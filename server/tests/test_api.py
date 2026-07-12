import http.client
import json
import tempfile
import threading
import unittest
from pathlib import Path

from db.connection import connect
from db.migrations import migrate
from db.repository import publish_edition, replace_topics
from server.app import ServerConfig, create_server


ROOT = Path(__file__).resolve().parents[2]


class APITests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.path = Path(self.temporary.name) / "morrow.sqlite"
        connection = connect(self.path)
        migrate(connection)
        replace_topics(connection, json.loads((ROOT / "etl/seeds/default-topics.json").read_text(encoding="utf-8")))
        publish_edition(connection, json.loads((ROOT / "etl/seeds/first-edition.json").read_text(encoding="utf-8")))
        connection.close()
        self.server = create_server(ServerConfig(self.path, "secret", ("https://reader.example",), 512), port=0)
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
        data = json.loads(response.read())
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
