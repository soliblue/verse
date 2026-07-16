import json
import sqlite3
import tempfile
import threading
import unittest
from concurrent.futures import ThreadPoolExecutor
from copy import deepcopy
from pathlib import Path

from db.connection import connect
from db.migrations import migrate
from db.repository import (
    current_edition,
    edition_summaries,
    publish_edition,
    queue_deep_dive,
    record_feedback,
    replace_topics,
    store_deep_dive,
    topics,
)
from db.seed import seed_database
from etl.validation import complete_edition, validate_edition


ROOT = Path(__file__).resolve().parents[2]


class RepositoryTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.path = Path(self.temporary.name) / "verse.sqlite"
        self.connection = connect(self.path)
        migrate(self.connection)
        self.edition = json.loads((ROOT / "etl/seeds/first-edition.json").read_text(encoding="utf-8"))
        self.topic_payload = json.loads((ROOT / "etl/seeds/default-topics.json").read_text(encoding="utf-8"))

    def tearDown(self):
        self.connection.close()
        self.temporary.cleanup()

    def test_migrations_are_repeatable(self):
        self.assertEqual(migrate(self.connection), [])
        self.assertEqual(self.connection.execute("SELECT count(*) FROM schema_migrations").fetchone()[0], 5)

    def test_publish_is_repeatable_and_materialized(self):
        first = publish_edition(self.connection, self.edition)
        second = publish_edition(self.connection, self.edition)
        self.assertEqual(first, second)
        self.assertEqual(current_edition(self.connection), first)
        self.assertEqual(len(edition_summaries(self.connection)["editions"]), 1)
        self.assertEqual(self.connection.execute("SELECT count(*) FROM edition_items").fetchone()[0], 10)
        stored_evidence = json.loads(
            self.connection.execute(
                "SELECT evidence_json FROM edition_items ORDER BY position LIMIT 1"
            ).fetchone()[0]
        )
        self.assertEqual(stored_evidence["source"]["url"], first["items"][0]["source_url"])
        self.assertTrue(stored_evidence["source"]["content"])
        stored_provenance = json.loads(
            self.connection.execute(
                "SELECT model_provenance_json FROM edition_items ORDER BY position LIMIT 1"
            ).fetchone()[0]
        )
        self.assertEqual(stored_provenance["provider"], "curated_seed")
        self.assertEqual(stored_provenance["researched_at"], first["generated_at"])
        self.assertEqual(first["items"][0]["feedback"]["saved"], False)
        self.assertEqual(first["items"][0]["deep_dive"]["status"], "not_requested")

    def test_invalid_publish_preserves_current_edition(self):
        published = publish_edition(self.connection, self.edition)
        invalid = deepcopy(self.edition)
        invalid["id"] = "invalid"
        invalid["items"][0]["citations"][0]["url"] = "not-a-url"
        with self.assertRaises(ValueError):
            publish_edition(self.connection, invalid)
        self.assertEqual(current_edition(self.connection), published)

    def test_feedback_and_deep_dive_update_materialized_payload(self):
        publish_edition(self.connection, self.edition)
        story_id = self.edition["items"][0]["id"]
        state = record_feedback(self.connection, story_id, "saved", True)
        self.assertTrue(state["saved"])
        self.assertTrue(current_edition(self.connection)["items"][0]["feedback"]["saved"])
        preference = record_feedback(self.connection, story_id, "more_like_this", True)
        self.assertEqual(preference["preference"], "more_like_this")
        cleared = record_feedback(self.connection, story_id, "more_like_this", False)
        self.assertIsNone(cleared["preference"])
        queued = queue_deep_dive(self.connection, story_id)
        repeated = queue_deep_dive(self.connection, story_id)
        self.assertEqual(queued, repeated)
        self.assertEqual(current_edition(self.connection)["items"][0]["deep_dive"]["status"], "queued")
        self.assertEqual(self.connection.execute("SELECT count(*) FROM feedback_events").fetchone()[0], 3)

    def test_writes_reject_unknown_stories(self):
        with self.assertRaises(LookupError):
            record_feedback(self.connection, "missing", "seen", True)
        with self.assertRaises(LookupError):
            queue_deep_dive(self.connection, "missing")

    def test_ready_deep_dive_is_materialized_with_evidence(self):
        publish_edition(self.connection, self.edition)
        story = self.edition["items"][0]
        queue_deep_dive(self.connection, story["id"])
        payload = {"title": "A closer look", "body": "A deeper synthesis of the stored source evidence.", "citations": story["citations"]}
        with self.connection:
            store_deep_dive(self.connection, story["id"], payload, {"provider": "test"})
        item = next(item for item in current_edition(self.connection)["items"] if item["id"] == story["id"])
        self.assertEqual(item["deep_dive"]["status"], "ready")
        self.assertEqual(item["deep_dive"]["citations"], story["citations"])

    def test_ready_deep_dive_rejects_unstored_citations(self):
        publish_edition(self.connection, self.edition)
        story = self.edition["items"][0]
        queue_deep_dive(self.connection, story["id"])
        citation = {"title": "Invented", "url": "https://example.com/invented", "source_name": "Unknown", "published_at": None}
        with self.assertRaisesRegex(ValueError, "stored source evidence"):
            store_deep_dive(
                self.connection,
                story["id"],
                {"title": "Invalid", "body": "This must not be stored.", "citations": [citation]},
                {"provider": "test"},
            )
        self.assertEqual(current_edition(self.connection)["items"][0]["deep_dive"]["status"], "queued")

    def test_deep_dive_can_finish_from_an_older_edition_citation(self):
        publish_edition(self.connection, self.edition)
        story = self.edition["items"][0]
        original_citation = story["citations"][0]
        queue_deep_dive(self.connection, story["id"])
        newer = deepcopy(self.edition)
        newer["id"] = "edition-2026-07-13"
        newer["date"] = "2026-07-13"
        replacement = {**original_citation, "title": "Revised source", "url": "https://example.com/revised"}
        newer["items"][0]["citations"] = [replacement]
        publish_edition(self.connection, newer)

        store_deep_dive(
            self.connection,
            story["id"],
            {"title": "Closer look", "body": "Grounded in the earlier stored evidence.", "citations": [original_citation]},
            {"provider": "test"},
        )

        item = current_edition(self.connection)["items"][0]
        self.assertEqual(item["deep_dive"]["status"], "ready")
        self.assertEqual(item["citations"], [replacement, original_citation])

    def test_ready_deep_dive_survives_republication_with_revised_citations(self):
        publish_edition(self.connection, self.edition)
        story = self.edition["items"][0]
        original_citation = story["citations"][0]
        queue_deep_dive(self.connection, story["id"])
        store_deep_dive(
            self.connection,
            story["id"],
            {"title": "Closer look", "body": "Grounded in the original stored evidence.", "citations": [original_citation]},
            {"provider": "test"},
        )
        newer = deepcopy(self.edition)
        newer["id"] = "edition-2026-07-13"
        newer["date"] = "2026-07-13"
        replacement = {**original_citation, "title": "Revised source", "url": "https://example.com/revised"}
        newer["items"][0]["citations"] = [replacement]

        publish_edition(self.connection, newer)
        record_feedback(self.connection, story["id"], "seen", True)

        item = current_edition(self.connection)["items"][0]
        self.assertEqual(item["deep_dive"]["status"], "ready")
        self.assertEqual(item["citations"], [replacement, original_citation])

    def test_topic_replacement_is_repeatable_and_atomic(self):
        first = replace_topics(self.connection, self.topic_payload)
        second = replace_topics(self.connection, self.topic_payload)
        self.assertEqual(first, second)
        invalid = deepcopy(self.topic_payload)
        invalid["topics"][1]["position"] = invalid["topics"][0]["position"]
        with self.assertRaises(ValueError):
            replace_topics(self.connection, invalid)
        self.assertEqual(topics(self.connection), first)

    def test_complete_edition_adds_decode_safe_state(self):
        completed = complete_edition(self.edition)
        validate_edition(completed)
        self.assertIsNone(completed["items"][0]["image_url"])
        self.assertEqual(completed["items"][0]["deep_dive"]["citations"], [])

    def test_default_seed_preserves_operator_state(self):
        seed_database(self.connection, self.edition, self.topic_payload)
        self.connection.execute("UPDATE topics SET name = 'Operator topic' WHERE id = 'audiovisual-techniques'")
        self.connection.commit()
        newer = deepcopy(self.edition)
        newer["id"] = "edition-2026-07-13"
        newer["date"] = "2026-07-13"
        publish_edition(self.connection, newer)

        status = seed_database(self.connection, self.edition, self.topic_payload)

        self.assertEqual(status, {"topics": "kept", "edition": "kept"})
        self.assertEqual(
            self.connection.execute(
                "SELECT name FROM topics WHERE id = 'audiovisual-techniques'"
            ).fetchone()[0],
            "Operator topic",
        )
        self.assertEqual(current_edition(self.connection)["id"], "edition-2026-07-13")


class MigrationIntegrityTests(unittest.TestCase):
    def test_concurrent_migrations_serialize(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "db.sqlite"
            barrier = threading.Barrier(4)

            def apply():
                barrier.wait()
                connection = connect(path)
                result = migrate(connection)
                connection.close()
                return result

            with ThreadPoolExecutor(max_workers=4) as executor:
                results = list(executor.map(lambda _: apply(), range(4)))
            self.assertEqual(sum(len(result) for result in results), 5)
            connection = connect(path)
            self.assertEqual(connection.execute("SELECT count(*) FROM schema_migrations").fetchone()[0], 5)
            connection.close()

    def test_changed_applied_migration_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            migrations = root / "migrations"
            migrations.mkdir()
            source = ROOT / "db/migrations/001_initial.sql"
            target = migrations / source.name
            target.write_text(source.read_text(encoding="utf-8"), encoding="utf-8")
            connection = sqlite3.connect(root / "db.sqlite")
            connection.row_factory = sqlite3.Row
            migrate(connection, migrations)
            target.write_text(target.read_text(encoding="utf-8") + "\n", encoding="utf-8")
            with self.assertRaises(RuntimeError):
                migrate(connection, migrations)
            connection.close()


if __name__ == "__main__":
    unittest.main()
