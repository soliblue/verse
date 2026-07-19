import json
import shutil
import tempfile
import unittest
from copy import deepcopy
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

from db.connection import connect
from db.content import index_edition, related_stories, sync_content
from db.explore import (
    current_explore,
    event_ranking_profile,
    publish_explore,
    record_event_feedback,
    record_venue_feedback,
)
from db.migrations import migrate
from db.repository import edition, publish_edition, record_feedback
from db.state import deep_dive_state
from etl.content import (
    load_edition,
    parse_document,
    parse_preferences,
    render_document,
    write_deep_dive,
    write_edition,
    write_preferences,
    write_preferences_markdown,
)
from etl.explore import build_explore, distance_band, materialize_explore, validate_explore


ROOT = Path(__file__).resolve().parents[2]


class MarkdownContentTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name) / "content"
        self.edition = json.loads((ROOT / "etl/seeds/first-edition.json").read_text(encoding="utf-8"))
        self.topics = json.loads((ROOT / "etl/seeds/default-topics.json").read_text(encoding="utf-8"))

    def tearDown(self):
        self.temporary.cleanup()

    def test_markdown_round_trip_preserves_transport_contract_without_covers(self):
        payload, index = write_edition(self.edition, self.root, public_base_url="https://verse.example")

        self.assertEqual(payload["id"], self.edition["id"])
        self.assertEqual(len(payload["items"]), 10)
        self.assertEqual(payload["items"][0]["body"], self.edition["items"][0]["body"])
        self.assertEqual(payload["items"][0]["citations"], self.edition["items"][0]["citations"])
        self.assertIsNone(payload["items"][0]["image_url"])
        self.assertEqual(len(index["stories"]), 10)
        self.assertFalse((self.root / "editions/2026-07-12/assets").exists())
        story_metadata, _ = load_edition(self.root / "editions/2026-07-12/edition.md")
        self.assertTrue(all(item["image_url"] is None for item in story_metadata["items"]))

    def test_historical_covers_remain_readable(self):
        payload, _ = load_edition(
            ROOT / "content/editions/2026-07-12/edition.md",
            public_base_url="https://verse.example",
        )

        self.assertEqual(
            payload["items"][0]["image_url"],
            "https://verse.example/v1/assets/2026-07-12/assets/meta-physics-video-world-models-2026.png",
        )

    def test_preferences_round_trip_is_human_editable(self):
        path = self.root / "preferences.md"
        write_preferences(path, self.topics)

        self.assertEqual(parse_preferences(path), self.topics)

    def test_preferences_markdown_is_preserved_exactly(self):
        path = self.root / "preferences.md"
        write_preferences(path, self.topics)
        markdown = path.read_text(encoding="utf-8").replace(
            "Methods for composing, synchronizing, rendering, and presenting sound and moving image.",
            "Methods for composing, synchronizing, rendering, and presenting sound and moving image.\n\n<!-- personal note -->",
        )
        parsed = write_preferences_markdown(path, markdown)
        self.assertEqual(path.read_text(encoding="utf-8"), markdown)
        self.assertIn("personal note", parsed["topics"][0]["description"])
        text = path.read_text(encoding="utf-8")
        self.assertIn("## Audiovisual techniques", text)
        self.assertIn("- kind: \"interest\"", text)

    def test_sync_rebuilds_indexes_and_preserves_feedback(self):
        write_preferences(self.root / "preferences.md", self.topics)
        first, first_index = write_edition(self.edition, self.root)
        path = Path(self.temporary.name) / "verse.sqlite"
        connection = connect(path)
        migrate(connection)

        status = sync_content(connection, self.root)
        story_id = first["items"][0]["id"]
        record_feedback(connection, story_id, "saved", True)
        self.assertEqual(status, {"preferences": 1, "editions": 1, "stories": 10, "deep_dives": 0})
        self.assertEqual(connection.execute("SELECT count(*) FROM story_documents").fetchone()[0], 10)
        write_deep_dive(
            self.root,
            story_id,
            {
                "title": "A closer look",
                "body": "An editable synthesis grounded in the original evidence.",
                "citations": first["items"][0]["citations"],
            },
            {"provider": "test", "model": "fixture", "completed_at": "2026-07-12T07:00:00Z"},
        )
        self.assertEqual(sync_content(connection, self.root)["deep_dives"], 1)
        self.assertEqual(deep_dive_state(connection, story_id)["title"], "A closer look")

        second_source = deepcopy(self.edition)
        second_source["id"] = "edition-2026-07-13"
        second_source["date"] = "2026-07-13"
        second_source["generated_at"] = "2026-07-13T06:00:00Z"
        second_source["items"][0]["id"] = "physics-world-models-followup"
        second_source["items"][0]["related_story_ids"] = [story_id]
        second, second_index = write_edition(second_source, self.root)
        publish_edition(connection, second)
        index_edition(connection, second, second_index, self.root)

        relation = related_stories(connection, second["items"][0]["id"])
        self.assertEqual(relation["stories"][0]["item"]["id"], story_id)
        self.assertEqual(relation["stories"][0]["relation"], "related")
        sync_content(connection, self.root)
        older = next(item for item in edition(connection, first["id"])["items"] if item["id"] == story_id)
        self.assertTrue(older["feedback"]["saved"])
        connection.close()

    def test_unsafe_story_paths_are_rejected(self):
        write_edition(self.edition, self.root)
        path = self.root / "editions/2026-07-12/edition.md"
        text = path.read_text(encoding="utf-8").replace(
            '"01-meta-physics-video-world-models-2026.md"',
            '"../preferences.md"',
        )
        path.write_text(text, encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "unsafe"):
            load_edition(path)

class ExploreContentTests(unittest.TestCase):
    def test_materialized_fixture_is_finite_deduplicated_and_berlin_local(self):
        now = datetime(2026, 7, 16, 8, 30, tzinfo=ZoneInfo("Europe/Berlin"))
        payload = materialize_explore(ROOT / "content", now=now)

        validate_explore(payload)
        self.assertEqual(payload["timezone"], "Europe/Berlin")
        self.assertGreater(len(payload["featured_events"]), 0)
        self.assertLessEqual(len(payload["featured_events"]), 12)
        self.assertEqual(len(payload["events"]), len(payload["calendar"]))
        self.assertEqual(
            {item["occurrence"]["id"] for item in payload["events"]},
            {item["id"] for item in payload["calendar"]},
        )
        series = [item["series_id"] or item["id"] for item in payload["featured_events"]]
        self.assertEqual(len(series), len(set(series)))
        self.assertTrue(all(item["occurrence"]["state"] == "upcoming" for item in payload["featured_events"]))
        serialized = json.dumps(payload)
        self.assertNotIn("home_latitude", serialized)
        self.assertNotIn("home_longitude", serialized)
        self.assertNotIn("VERSE_PROXIMITY_ANCHOR", serialized)
        self.assertEqual({venue["distance_band"] for venue in payload["venues"]}, {"unknown"})

    def test_distance_is_computed_only_from_an_explicit_private_anchor(self):
        venue = {"latitude": 52.5005, "longitude": 13.4005}
        self.assertEqual(distance_band(venue, None), "unknown")
        self.assertEqual(distance_band(venue, (52.5, 13.4)), "walkable")

    def test_event_can_carry_a_non_watched_venue(self):
        now = datetime(2026, 7, 16, 8, 30, tzinfo=ZoneInfo("Europe/Berlin"))
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "content"
            shutil.copytree(ROOT / "content", root)
            baseline = build_explore(root, now=now)[0]
            featured = baseline["featured_events"][0]
            path = next(
                path
                for path in (root / "events" / "upcoming").glob("*.md")
                if f'occurrence_id: "{featured["occurrence"]["id"]}"' in path.read_text(encoding="utf-8")
            )
            metadata, body = parse_document(path)
            metadata.update(
                {
                    "venue_id": "discovered-venue",
                    "venue_name": "Discovered Venue",
                    "venue_address": "Example Street 1, 10115 Berlin",
                    "venue_neighborhood": "Mitte",
                    "venue_official_url": "https://example.com/venue",
                    "venue_calendar_url": None,
                    "venue_latitude": None,
                    "venue_longitude": None,
                }
            )
            path.write_text(render_document(metadata, body), encoding="utf-8")

            payload = build_explore(root, now=now)[0]
            event = next(item for item in payload["events"] if item["id"] == featured["id"])
            self.assertEqual(event["venue"]["name"], "Discovered Venue")
            self.assertNotIn("discovered-venue", {venue["id"] for venue in payload["venues"]})
            self.assertIn("discovered-venue", {item["venue"]["id"] for item in payload["featured_events"]})

            muted = build_explore(
                root,
                now=now,
                ranking_profile={"categories": {}, "venues": {}, "watch_states": {"discovered-venue": "muted"}},
            )[0]
            self.assertNotIn("discovered-venue", {item["venue"]["id"] for item in muted["featured_events"]})
            muted_event = next(item for item in muted["events"] if item["id"] == featured["id"])
            self.assertEqual(muted_event["venue"]["watch_state"], "muted")

    def test_explore_repository_keeps_feedback_and_ranking_profile(self):
        now = datetime(2026, 7, 16, 8, 30, tzinfo=ZoneInfo("Europe/Berlin"))
        payload, source_events = build_explore(ROOT / "content", now=now)
        with tempfile.TemporaryDirectory() as directory:
            connection = connect(Path(directory) / "verse.sqlite")
            migrate(connection)
            publish_explore(connection, payload, source_events)
            event = payload["featured_events"][0]
            state = record_event_feedback(
                connection,
                event["id"],
                event["occurrence"]["id"],
                "loved",
                True,
            )

            self.assertTrue(state["signals"]["loved"])
            self.assertEqual(current_explore(connection)["id"], payload["id"])
            expected_occurrences = len({item["occurrence"]["id"] for item in source_events})
            self.assertEqual(
                connection.execute("SELECT count(*) FROM event_occurrences").fetchone()[0],
                expected_occurrences,
            )
            profile = event_ranking_profile(connection)
            self.assertTrue(all(profile["categories"][category] > 0 for category in event["categories"]))
            venue_id = event["venue"]["id"]
            self.assertGreater(profile["venues"][venue_id], 0)

            record_venue_feedback(connection, venue_id, "more_from_here", True)
            record_venue_feedback(connection, venue_id, "mute", True)
            profile = event_ranking_profile(connection)
            self.assertEqual(profile["watch_states"][venue_id], "muted")
            rebuilt, rebuilt_sources = build_explore(ROOT / "content", now=now, ranking_profile=profile)
            self.assertNotIn(venue_id, {venue["id"] for venue in rebuilt["venues"]})
            self.assertTrue(all(item["venue"]["id"] != venue_id for item in rebuilt["featured_events"]))
            self.assertTrue(
                all(
                    item["venue"]["watch_state"] == "muted"
                    for item in rebuilt["events"]
                    if item["venue"]["id"] == venue_id
                )
            )
            publish_explore(connection, rebuilt, rebuilt_sources)
            self.assertEqual(current_explore(connection)["id"], rebuilt["id"])
            connection.close()

    def test_attended_history_uses_durable_feedback_and_only_ended_occurrences(self):
        now = datetime(2026, 7, 16, 8, 30, tzinfo=ZoneInfo("Europe/Berlin"))
        payload, source_events = build_explore(ROOT / "content", now=now)
        self.assertEqual(payload["attended_events"], [])
        with tempfile.TemporaryDirectory() as directory:
            connection = connect(Path(directory) / "verse.sqlite")
            migrate(connection)
            publish_explore(connection, payload, source_events)
            live = payload["featured_events"][0]
            record_event_feedback(connection, live["id"], live["occurrence"]["id"], "attended", True)

            profile = event_ranking_profile(connection)
            self.assertEqual(
                profile["attended_occurrence_ids"],
                sorted([live["occurrence"]["id"], "sputnik-open-screening-attended"]),
            )
            rebuilt = build_explore(ROOT / "content", now=now, ranking_profile=profile)[0]
            self.assertEqual(
                [item["occurrence"]["id"] for item in rebuilt["attended_events"]],
                ["sputnik-open-screening-attended"],
            )
            self.assertTrue(all(item["occurrence"]["state"] == "ended" for item in rebuilt["attended_events"]))
            self.assertLessEqual(len(rebuilt["attended_events"]), 12)

            invalid = deepcopy(rebuilt)
            invalid["attended_events"] = [deepcopy(rebuilt["attended_events"][0]) for _ in range(13)]
            with self.assertRaisesRegex(ValueError, "at most 12"):
                validate_explore(invalid)
            invalid = deepcopy(rebuilt)
            invalid["attended_events"] = [deepcopy(live)]
            with self.assertRaisesRegex(ValueError, "only ended"):
                validate_explore(invalid)

            record_event_feedback(
                connection,
                "sputnik-open-screening-taste-example",
                "sputnik-open-screening-attended",
                "attended",
                False,
            )
            profile = event_ranking_profile(connection)
            rebuilt = build_explore(ROOT / "content", now=now, ranking_profile=profile)[0]
            self.assertEqual(rebuilt["attended_events"], [])
            connection.close()

    def test_prior_featured_events_are_suppressed_until_a_meaningful_update(self):
        first_now = datetime(2026, 7, 16, 8, 30, tzinfo=ZoneInfo("Europe/Berlin"))
        second_now = datetime(2026, 7, 17, 8, 30, tzinfo=ZoneInfo("Europe/Berlin"))
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "content"
            shutil.copytree(ROOT / "content", root)
            connection = connect(Path(directory) / "verse.sqlite")
            migrate(connection)
            first, sources = build_explore(root, now=first_now)
            publish_explore(connection, first, sources)
            without_history = build_explore(root, now=second_now)[0]
            repeated = {
                item["occurrence"]["id"] for item in first["featured_events"]
            } & {
                item["occurrence"]["id"] for item in without_history["featured_events"]
            }
            self.assertTrue(repeated)

            profile = event_ranking_profile(connection)
            second = build_explore(root, now=second_now, ranking_profile=profile)[0]
            self.assertTrue(repeated.isdisjoint({item["occurrence"]["id"] for item in second["featured_events"]}))
            self.assertTrue(repeated <= {item["id"] for item in second["calendar"]})
            first_series = {item["series_id"] or item["id"] for item in first["featured_events"]}
            second_series = {item["series_id"] or item["id"] for item in second["featured_events"]}
            self.assertTrue(first_series.isdisjoint(second_series))

            occurrence_id = sorted(repeated)[0]
            path = next(
                path
                for path in (root / "events" / "upcoming").glob("*.md")
                if f'occurrence_id: "{occurrence_id}"' in path.read_text(encoding="utf-8")
            )
            text = path.read_text(encoding="utf-8")
            for novelty in ("meaningful_update", "final_chance"):
                path.write_text(text.replace('novelty: "new"', f'novelty: "{novelty}"'), encoding="utf-8")
                updated = build_explore(root, now=second_now, ranking_profile=profile)[0]
                self.assertIn(occurrence_id, {item["occurrence"]["id"] for item in updated["featured_events"]})
            connection.close()


if __name__ == "__main__":
    unittest.main()
