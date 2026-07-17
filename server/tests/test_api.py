import http.client
import json
import tempfile
import threading
import unittest
from pathlib import Path

from db.connection import connect
from db.explore import publish_explore
from db.migrations import migrate
from db.repository import publish_edition, replace_topics
from etl.content import write_preferences
from server.app import ServerConfig, create_server


ROOT = Path(__file__).resolve().parents[2]


class APITests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.path = Path(self.temporary.name) / "verse.sqlite"
        self.content = Path(self.temporary.name) / "content"
        connection = connect(self.path)
        migrate(connection)
        topic_payload = json.loads((ROOT / "etl/seeds/default-topics.json").read_text(encoding="utf-8"))
        replace_topics(connection, topic_payload)
        write_preferences(self.content / "preferences.md", topic_payload)
        publish_edition(connection, json.loads((ROOT / "etl/seeds/first-edition.json").read_text(encoding="utf-8")))
        publish_explore(connection, json.loads((ROOT / "content/explore/current.json").read_text(encoding="utf-8")))
        connection.close()
        self.server = create_server(
            ServerConfig(
                self.path,
                "secret",
                ("https://reader.example",),
                512,
                content_path=self.content,
                public_base_url="https://verse.example",
            ),
            port=0,
        )
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()
        self.temporary.cleanup()

    def request(self, method, path, payload=None, authorized=True, headers=None):
        body = None if payload is None else (payload if isinstance(payload, bytes) else json.dumps(payload).encode())
        request_headers = dict(headers or {})
        if authorized:
            request_headers["Authorization"] = "Bearer secret"
        if payload is not None and "Content-Type" not in request_headers:
            request_headers["Content-Type"] = "application/json"
        connection = http.client.HTTPConnection("127.0.0.1", self.server.server_port, timeout=3)
        connection.request(method, path, body=body, headers=request_headers)
        response = connection.getresponse()
        raw = response.read()
        data = json.loads(raw) if response.getheader("Content-Type", "").startswith("application/json") else raw
        result = response.status, data, dict(response.headers)
        connection.close()
        return result

    def test_health_is_public(self):
        status, payload, _ = self.request("GET", "/health", authorized=False)
        self.assertEqual(status, 200)
        self.assertEqual(payload["status"], "ok")
        self.assertEqual(payload["current_edition_id"], "edition-2026-07-12")

    def test_private_routes_require_bearer_secret(self):
        status, payload, headers = self.request("GET", "/v1/edition/today", authorized=False)
        self.assertEqual(status, 401)
        self.assertEqual(payload["error"]["code"], "unauthorized")
        self.assertIn("Bearer", headers["WWW-Authenticate"])

    def test_private_routes_are_open_when_secret_is_unset(self):
        self.server.config = ServerConfig(self.path, None, (), 512, True)
        status, payload, _ = self.request("GET", "/v1/edition/today", authorized=False)
        self.assertEqual(status, 200)
        self.assertEqual(payload["id"], "edition-2026-07-12")

    def test_edition_reads_are_complete(self):
        status, today, _ = self.request("GET", "/v1/edition/today")
        self.assertEqual(status, 200)
        self.assertEqual(len(today["items"]), 10)
        self.assertIn("feedback", today["items"][0])
        status, summaries, _ = self.request("GET", "/v1/editions")
        self.assertEqual(status, 200)
        self.assertEqual(summaries["editions"][0]["item_count"], 10)
        status, archived, _ = self.request("GET", "/v1/editions/edition-2026-07-12")
        self.assertEqual(status, 200)
        self.assertEqual(archived, today)

    def test_topics_can_be_replaced(self):
        status, current, _ = self.request("GET", "/v1/topics")
        self.assertEqual(status, 200)
        updated = {"topics": current["topics"][:2]}
        updated["topics"][0]["name"] = "Updated interest"
        status, saved, _ = self.request("PUT", "/v1/topics", updated)
        self.assertEqual(status, 200)
        self.assertEqual(saved, updated)
        self.assertTrue((self.content / "preferences.md").is_file())

    def test_preferences_markdown_round_trip_is_lossless(self):
        status, current, _ = self.request("GET", "/v1/preferences")
        self.assertEqual(status, 200)
        self.assertIn("# Preferences", current["markdown"])
        markdown = (
            "---\nversion: 1\n---\n\n# Preferences\n\n"
            "## Spatial sound\n"
            "- id: spatial-sound\n"
            "- kind: interest\n"
            "- enabled: true\n"
            "- position: 1\n\n"
            "Room-scale listening.\n\n"
            "<!-- keep this note exactly -->\n"
        )
        status, saved, _ = self.request("PUT", "/v1/preferences", {"markdown": markdown})
        self.assertEqual(status, 200)
        self.assertEqual(saved, {"markdown": markdown})
        self.assertEqual((self.content / "preferences.md").read_text(encoding="utf-8"), markdown)
        status, topics, _ = self.request("GET", "/v1/topics")
        self.assertEqual(status, 200)
        self.assertIn("keep this note exactly", topics["topics"][0]["description"])

    def test_invalid_preferences_preserve_file_and_database(self):
        before_file = (self.content / "preferences.md").read_text(encoding="utf-8")
        _, before_topics, _ = self.request("GET", "/v1/topics")
        status, payload, _ = self.request(
            "PUT",
            "/v1/preferences",
            {"markdown": "# Anything at all\n"},
        )
        self.assertEqual(status, 400)
        self.assertEqual(payload["error"]["code"], "invalid_request")
        self.assertEqual((self.content / "preferences.md").read_text(encoding="utf-8"), before_file)
        _, after_topics, _ = self.request("GET", "/v1/topics")
        self.assertEqual(after_topics, before_topics)

    def test_feedback_persists_into_edition_payload(self):
        story_id = "meta-physics-video-world-models-2026"
        status, response, _ = self.request("POST", "/v1/feedback", {"story_id": story_id, "kind": "saved", "value": True})
        self.assertEqual(status, 200)
        self.assertTrue(response["feedback"]["saved"])
        _, today, _ = self.request("GET", "/v1/edition/today")
        item = next(item for item in today["items"] if item["id"] == story_id)
        self.assertTrue(item["feedback"]["saved"])

    def test_feedback_idempotency_key_prevents_duplicate_events(self):
        request = {
            "story_id": "meta-physics-video-world-models-2026",
            "kind": "saved",
            "value": True,
        }
        headers = {"Idempotency-Key": "mutation-1"}
        first = self.request("POST", "/v1/feedback", request, headers=headers)
        second = self.request("POST", "/v1/feedback", request, headers=headers)
        self.assertEqual(first[:2], second[:2])
        connection = connect(self.path)
        self.assertEqual(connection.execute("SELECT count(*) FROM feedback_events").fetchone()[0], 1)
        connection.close()
        request["value"] = False
        status, payload, _ = self.request("POST", "/v1/feedback", request, headers=headers)
        self.assertEqual((status, payload["error"]["code"]), (409, "idempotency_conflict"))

    def test_deep_dive_queue_is_idempotent(self):
        request = {"story_id": "meta-physics-video-world-models-2026"}
        first = self.request("POST", "/v1/deep-dives", request)
        second = self.request("POST", "/v1/deep-dives", request)
        self.assertEqual(first[0], 202)
        self.assertEqual(first[1], second[1])
        self.assertEqual(first[1]["deep_dive"]["status"], "queued")

    def test_explore_venues_and_event_feedback_are_available(self):
        status, explore, _ = self.request("GET", "/v1/explore")
        self.assertEqual(status, 200)
        self.assertLessEqual(len(explore["featured_events"]), 12)
        self.assertLessEqual(len(explore["attended_events"]), 12)
        self.assertTrue(
            all(event["occurrence"]["state"] == "ended" for event in explore["attended_events"])
        )
        self.assertEqual(len(explore["events"]), len(explore["calendar"]))
        self.assertEqual(
            {event["occurrence"]["id"] for event in explore["events"]},
            {occurrence["id"] for occurrence in explore["calendar"]},
        )
        status, venues, _ = self.request("GET", "/v1/venues")
        self.assertEqual(status, 200)
        self.assertEqual(venues["venues"], explore["venues"])
        event = explore["featured_events"][0]
        request = {
            "event_id": event["id"],
            "occurrence_id": event["occurrence"]["id"],
            "kind": "loved",
            "value": True,
        }
        first = self.request("POST", "/v1/event-feedback", request, headers={"Idempotency-Key": "event-1"})
        second = self.request("POST", "/v1/event-feedback", request, headers={"Idempotency-Key": "event-1"})
        self.assertEqual(first[:2], second[:2])
        self.assertTrue(first[1]["feedback"]["signals"]["loved"])
        connection = connect(self.path)
        self.assertEqual(connection.execute("SELECT count(*) FROM event_feedback_events").fetchone()[0], 1)
        connection.close()

    def test_venue_feedback_is_durable_and_updates_explore(self):
        more = {
            "venue_id": "thf-tower",
            "kind": "more_from_here",
            "value": True,
        }
        first = self.request("POST", "/v1/venue-feedback", more, headers={"Idempotency-Key": "venue-1"})
        second = self.request("POST", "/v1/venue-feedback", more, headers={"Idempotency-Key": "venue-1"})
        self.assertEqual(first[:2], second[:2])
        self.assertTrue(first[1]["feedback"]["more_from_here"])
        self.assertEqual(first[1]["venue"]["watch_state"], "favorite")

        mute = {"venue_id": "thf-tower", "kind": "mute", "value": True}
        status, response, _ = self.request(
            "POST",
            "/v1/venue-feedback",
            mute,
            headers={"Idempotency-Key": "venue-2"},
        )
        self.assertEqual(status, 200)
        self.assertTrue(response["feedback"]["muted"])
        self.assertEqual(response["venue"]["watch_state"], "muted")

        status, venues, _ = self.request("GET", "/v1/venues")
        self.assertEqual(status, 200)
        self.assertNotIn("thf-tower", {venue["id"] for venue in venues["venues"]})
        status, explore, _ = self.request("GET", "/v1/explore")
        self.assertEqual(status, 200)
        self.assertTrue(all(event["venue"]["id"] != "thf-tower" for event in explore["featured_events"]))
        self.assertEqual(
            {event["occurrence"]["id"] for event in explore["events"]},
            {occurrence["id"] for occurrence in explore["calendar"]},
        )
        thf_events = [event for event in explore["events"] if event["venue"]["id"] == "thf-tower"]
        self.assertTrue(thf_events)
        self.assertTrue(all(event["venue"]["watch_state"] == "muted" for event in thf_events))

        connection = connect(self.path)
        self.assertEqual(connection.execute("SELECT count(*) FROM venue_feedback_events").fetchone()[0], 2)
        connection.close()
        status, payload, _ = self.request(
            "POST",
            "/v1/event-feedback",
            {"event_id": "venue:thf-tower", "kind": "more_from_venue", "value": True},
        )
        self.assertEqual((status, payload["error"]["code"]), (404, "not_found"))

    def test_cover_assets_are_authenticated_and_paths_are_bounded(self):
        assets = self.content / "editions/2026-07-12/assets"
        assets.mkdir(parents=True)
        cover = assets / "story.png"
        cover.write_bytes(b"\x89PNG\r\n\x1a\nfixture")
        connection = connect(self.path)
        now = "2026-07-16T06:30:00Z"
        connection.execute(
            "INSERT INTO story_documents "
            "(story_id, markdown_path, content_sha256, cover_path, cover_is_fallback, indexed_at) "
            "VALUES (?, ?, ?, ?, 1, ?)",
            (
                "meta-physics-video-world-models-2026",
                "editions/2026-07-12/01-story.md",
                "fixture",
                "editions/2026-07-12/assets/story.png",
                now,
            ),
        )
        connection.commit()
        connection.close()

        status, today, _ = self.request("GET", "/v1/edition/today")
        self.assertEqual(status, 200)
        self.assertEqual(
            today["items"][0]["image_url"],
            "https://verse.example/v1/assets/2026-07-12/assets/story.png",
        )
        status, body, headers = self.request("GET", "/v1/assets/2026-07-12/assets/story.png")
        self.assertEqual((status, body, headers["Content-Type"]), (200, cover.read_bytes(), "image/png"))
        status, payload, _ = self.request(
            "GET",
            "/v1/assets/2026-07-12/assets/story.png",
            authorized=False,
        )
        self.assertEqual((status, payload["error"]["code"]), (401, "unauthorized"))
        status, payload, _ = self.request("GET", "/v1/assets/..%2Fserver%2F.env")
        self.assertEqual((status, payload["error"]["code"]), (404, "asset_not_found"))

    def test_related_story_route_is_bidirectional(self):
        source = "meta-physics-video-world-models-2026"
        target = "foley-omni-complete-soundtracks-2026"
        connection = connect(self.path)
        connection.execute(
            "INSERT INTO story_relations "
            "(source_story_id, target_story_id, relation, score, evidence, created_at, updated_at) "
            "VALUES (?, ?, 'related', 1, 'fixture', ?, ?)",
            (source, target, "2026-07-16T06:30:00Z", "2026-07-16T06:30:00Z"),
        )
        connection.commit()
        connection.close()
        status, payload, _ = self.request("GET", f"/v1/stories/{target}/related")
        self.assertEqual(status, 200)
        self.assertEqual(payload["stories"][0]["item"]["id"], source)

    def test_json_errors_are_bounded_and_structured(self):
        status, payload, _ = self.request("POST", "/v1/feedback", b"{", headers={"Content-Type": "application/json"})
        self.assertEqual((status, payload["error"]["code"]), (400, "invalid_json"))
        status, payload, _ = self.request("POST", "/v1/feedback", {"story_id": "x"}, headers={"Content-Type": "text/plain"})
        self.assertEqual((status, payload["error"]["code"]), (415, "unsupported_media_type"))
        status, payload, _ = self.request("PUT", "/v1/topics", b"{" + b"x" * 600, headers={"Content-Type": "application/json"})
        self.assertEqual((status, payload["error"]["code"]), (413, "request_too_large"))
        status, payload, _ = self.request("GET", "/missing")
        self.assertEqual((status, payload["error"]["code"]), (404, "not_found"))

    def test_cors_is_emitted_only_for_configured_origin(self):
        _, _, allowed = self.request("GET", "/health", authorized=False, headers={"Origin": "https://reader.example"})
        _, _, denied = self.request("GET", "/health", authorized=False, headers={"Origin": "https://other.example"})
        self.assertEqual(allowed["Access-Control-Allow-Origin"], "https://reader.example")
        self.assertNotIn("Access-Control-Allow-Origin", denied)

    def test_unknown_story_and_invalid_method_return_json(self):
        status, payload, _ = self.request("POST", "/v1/deep-dives", {"story_id": "missing"})
        self.assertEqual((status, payload["error"]["code"]), (404, "not_found"))
        status, payload, _ = self.request("POST", "/v1/editions", {})
        self.assertEqual((status, payload["error"]["code"]), (405, "method_not_allowed"))
        status, payload, _ = self.request("DELETE", "/v1/topics")
        self.assertEqual((status, payload["error"]["code"]), (405, "method_not_allowed"))


if __name__ == "__main__":
    unittest.main()
