import json
import os
import sqlite3
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from db.connection import connect
from db.migrations import migrate
from db.repository import current_edition, publish_edition, queue_deep_dive, record_feedback, replace_topics
from etl.agent import agent_environment, resolved_model
from etl.collect import collect_stage, parse_json_feed, parse_json_ld_html, parse_xml_feed, term_present
from etl.deduplicate import deduplicate_stage
from etl.enrich import (
    deterministic_story,
    enrich_deep_dives,
    enrich_stage,
    queued_deep_dives,
    validate_agent_deep_dives,
    validate_agent_items,
)
from etl.normalize import canonical_url, normalize_stage
from etl.rank import exclusion_words, rank_stage
from etl.runs import run_stage, start_run
from etl.validation import complete_edition, validate_edition
from etl.write import write_stage


ROOT = Path(__file__).resolve().parents[2]


def collected_items(count=10):
    return [
        {
            "external_id": f"external-{index}",
            "title": f"Distinct research signal number {index}",
            "url": f"https://example.com/items/{index}?utm_source=test",
            "author": "Researcher",
            "published_at": f"2026-07-{index + 1:02d}T08:00:00Z",
            "content": f"This is substantive source material for signal {index}. It explains a useful audiovisual technique with enough detail for a morning edition.",
        }
        for index in range(count)
    ]


class PipelineTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.database = self.root / "verse.sqlite"
        self.sources = self.root / "sources.json"
        self.environment = patch.dict(os.environ, {"VERSE_CONTENT_DIR": str(self.root / "content")})
        self.environment.start()
        self.sources.write_text(
            json.dumps(
                {
                    "sources": [
                        {
                            "id": "test-source",
                            "name": "Test Source",
                            "url": "https://example.com/feed",
                            "format": "json",
                            "topic_ids": ["audiovisual-techniques"],
                            "quality": 0.9,
                        }
                    ]
                }
            ),
            encoding="utf-8",
        )
        self.connection = connect(self.database)
        migrate(self.connection)
        replace_topics(
            self.connection,
            json.loads((ROOT / "etl/seeds/default-topics.json").read_text(encoding="utf-8")),
        )
        publish_edition(
            self.connection,
            json.loads((ROOT / "etl/seeds/first-edition.json").read_text(encoding="utf-8")),
        )
        self.run_id = start_run(self.connection, "2026-07-13")

    def tearDown(self):
        self.connection.close()
        self.environment.stop()
        self.temporary.cleanup()

    def test_full_pipeline_publishes_validated_materialized_edition(self):
        with patch("etl.collect.fetch", return_value=collected_items()):
            self.assertEqual(run_stage(self.connection, self.run_id, "collect", lambda: collect_stage(self.connection, self.run_id, self.sources)), 10)
        self.assertEqual(run_stage(self.connection, self.run_id, "normalize", lambda: normalize_stage(self.connection, self.run_id)), 10)
        self.assertEqual(run_stage(self.connection, self.run_id, "deduplicate", lambda: deduplicate_stage(self.connection, self.run_id)), 10)
        self.assertEqual(run_stage(self.connection, self.run_id, "rank", lambda: rank_stage(self.connection, self.run_id)), 10)
        self.assertEqual(run_stage(self.connection, self.run_id, "enrich", lambda: enrich_stage(self.connection, self.run_id)), 10)
        with patch.dict(os.environ, {"VERSE_RUNS_DIR": str(self.root / "runs")}):
            self.assertEqual(run_stage(self.connection, self.run_id, "write", lambda: write_stage(self.connection, self.run_id)), 10)
        payload = current_edition(self.connection)
        validate_edition(payload)
        self.assertEqual(payload["date"], "2026-07-13")
        self.assertEqual(len(payload["items"]), 10)
        self.assertTrue(all(item["feedback"]["saved"] is False for item in payload["items"]))
        self.assertEqual(self.connection.execute("SELECT status FROM etl_runs WHERE id = ?", (self.run_id,)).fetchone()[0], "completed")
        self.assertEqual(self.connection.execute("SELECT count(*) FROM edition_items WHERE edition_id = ?", (payload["id"],)).fetchone()[0], 10)
        self.assertEqual(self.connection.execute("SELECT count(*) FROM draft_stories WHERE model_provenance_json LIKE '%deterministic%'").fetchone()[0], 10)
        self.assertTrue((self.root / "runs" / self.run_id / "edition.json").exists())

    def test_completed_stage_is_idempotent(self):
        calls = []
        with patch("etl.collect.fetch", return_value=collected_items()):
            action = lambda: (calls.append(True), collect_stage(self.connection, self.run_id, self.sources))[1]
            first = run_stage(self.connection, self.run_id, "collect", action)
            second = run_stage(self.connection, self.run_id, "collect", action)
        self.assertEqual((first, second, len(calls)), (10, 10, 1))

    def test_failed_stage_is_recorded_and_previous_edition_survives(self):
        before = current_edition(self.connection)
        with patch("etl.collect.fetch", side_effect=OSError("offline")):
            with self.assertRaises(RuntimeError):
                run_stage(self.connection, self.run_id, "collect", lambda: collect_stage(self.connection, self.run_id, self.sources))
        run = self.connection.execute("SELECT status, error FROM etl_runs WHERE id = ?", (self.run_id,)).fetchone()
        stage = self.connection.execute("SELECT status, error FROM etl_stage_results WHERE run_id = ?", (self.run_id,)).fetchone()
        self.assertEqual(run["status"], "failed")
        self.assertIn("offline", stage["error"])
        self.assertEqual(current_edition(self.connection), before)

    def test_artifact_failure_rolls_back_published_edition(self):
        before = current_edition(self.connection)
        with patch("etl.collect.fetch", return_value=collected_items()):
            collect_stage(self.connection, self.run_id, self.sources)
        normalize_stage(self.connection, self.run_id)
        deduplicate_stage(self.connection, self.run_id)
        rank_stage(self.connection, self.run_id)
        enrich_stage(self.connection, self.run_id)

        with patch("etl.write.write_artifact", side_effect=OSError("disk full")):
            with self.assertRaisesRegex(OSError, "disk full"):
                write_stage(self.connection, self.run_id)

        self.assertEqual(current_edition(self.connection), before)
        self.assertIsNone(
            self.connection.execute(
                "SELECT 1 FROM editions WHERE edition_date = '2026-07-13'"
            ).fetchone()
        )

    def test_deep_dive_failure_does_not_block_edition(self):
        seed_story = current_edition(self.connection)["items"][0]
        queue_deep_dive(self.connection, seed_story["id"])
        with patch("etl.collect.fetch", return_value=collected_items()):
            collect_stage(self.connection, self.run_id, self.sources)
        normalize_stage(self.connection, self.run_id)
        deduplicate_stage(self.connection, self.run_id)
        rank_stage(self.connection, self.run_id)
        rows = self.connection.execute(
            "SELECT c.normalized_item_id, c.rationale, n.* FROM run_candidates c "
            "JOIN normalized_items n ON n.id = c.normalized_item_id "
            "WHERE c.run_id = ? AND c.selected = 1 ORDER BY c.total_score DESC, n.id",
            (self.run_id,),
        ).fetchall()
        response = {
            "items": [
                {"normalized_item_id": row["normalized_item_id"], **deterministic_story(row)}
                for row in rows
            ],
            "deep_dives": [],
        }
        with patch(
            "etl.enrich.run_agent_json",
            side_effect=[(response, {"provider": "test"}), RuntimeError("deep dive failed")],
        ):
            self.assertEqual(enrich_stage(self.connection, self.run_id, use_agent=True), 10)
        self.assertEqual(
            self.connection.execute(
                "SELECT status FROM deep_dives WHERE story_id = ?", (seed_story["id"],)
            ).fetchone()[0],
            "failed",
        )
        with patch.dict(os.environ, {"VERSE_RUNS_DIR": str(self.root / "runs")}):
            self.assertEqual(write_stage(self.connection, self.run_id), 10)
        self.assertEqual(current_edition(self.connection)["date"], "2026-07-13")

    def test_partial_collection_keeps_successful_sources(self):
        payload = json.loads(self.sources.read_text(encoding="utf-8"))
        payload["sources"].append({**payload["sources"][0], "id": "working-source", "url": "https://example.com/other"})
        self.sources.write_text(json.dumps(payload), encoding="utf-8")
        with patch("etl.collect.fetch", side_effect=[OSError("offline"), collected_items()]):
            count = collect_stage(self.connection, self.run_id, self.sources)
        self.assertEqual(count, 10)
        statuses = [row[0] for row in self.connection.execute("SELECT status FROM etl_source_results ORDER BY source_id")]
        self.assertEqual(statuses, ["failed", "completed"])

    def test_collection_drops_invalid_item_urls_without_losing_source(self):
        items = collected_items()
        items[0]["url"] = "javascript:alert(1)"
        with patch("etl.collect.fetch", return_value=items):
            count = collect_stage(self.connection, self.run_id, self.sources)
        self.assertEqual(count, 9)
        self.assertEqual(self.connection.execute("SELECT count(*) FROM run_source_items").fetchone()[0], 9)

    def test_normalization_canonicalizes_source_and_citation_urls(self):
        items = collected_items()
        items[0]["url"] = "http://www.arxiv.org/abs/2607.01234v3?utm_source=test"
        with patch("etl.collect.fetch", return_value=items):
            collect_stage(self.connection, self.run_id, self.sources)
        normalize_stage(self.connection, self.run_id)
        row = self.connection.execute(
            "SELECT canonical_url, citations_json FROM normalized_items "
            "WHERE canonical_url LIKE '%2607.01234%'"
        ).fetchone()
        self.assertEqual(row["canonical_url"], "https://arxiv.org/abs/2607.01234")
        self.assertEqual(json.loads(row["citations_json"])[0]["url"], row["canonical_url"])

    def test_rerank_does_not_treat_same_date_edition_as_seen(self):
        with patch("etl.collect.fetch", return_value=collected_items(12)):
            collect_stage(self.connection, self.run_id, self.sources)
        normalize_stage(self.connection, self.run_id)
        deduplicate_stage(self.connection, self.run_id)
        rank_stage(self.connection, self.run_id)
        before = {
            row[0]
            for row in self.connection.execute(
                "SELECT normalized_item_id FROM run_candidates WHERE run_id = ? AND selected = 1",
                (self.run_id,),
            )
        }
        enrich_stage(self.connection, self.run_id)
        with patch.dict(os.environ, {"VERSE_RUNS_DIR": str(self.root / "runs")}):
            write_stage(self.connection, self.run_id)
        rank_stage(self.connection, self.run_id)
        after = {
            row[0]
            for row in self.connection.execute(
                "SELECT normalized_item_id FROM run_candidates WHERE run_id = ? AND selected = 1",
                (self.run_id,),
            )
        }
        self.assertEqual(after, before)

    def test_deduplication_marks_same_title(self):
        items = collected_items()
        items[1]["title"] = items[0]["title"]
        with patch("etl.collect.fetch", return_value=items):
            collect_stage(self.connection, self.run_id, self.sources)
        normalize_stage(self.connection, self.run_id)
        deduplicate_stage(self.connection, self.run_id)
        self.assertEqual(self.connection.execute("SELECT count(*) FROM run_candidates WHERE duplicate_of IS NOT NULL").fetchone()[0], 1)

    def test_exclusions_are_hard_constraints(self):
        items = collected_items(12)
        for index in range(8, 12):
            items[index]["title"] = f"Sponsored crypto NFT speculation {index}"
            items[index]["content"] = "Sponsored token markets and NFT speculation."
        with patch("etl.collect.fetch", return_value=items):
            collect_stage(self.connection, self.run_id, self.sources)
        normalize_stage(self.connection, self.run_id)
        deduplicate_stage(self.connection, self.run_id)

        self.assertEqual(rank_stage(self.connection, self.run_id), 8)
        self.assertEqual(
            self.connection.execute(
                "SELECT count(*) FROM run_candidates WHERE selected = 1 AND rationale LIKE '%excluded true%'"
            ).fetchone()[0],
            0,
        )

    def test_today_selects_at_most_two_berlin_events(self):
        payload = json.loads(self.sources.read_text(encoding="utf-8"))
        payload["sources"] = [
            {
                **payload["sources"][0],
                "id": "berlin-events",
                "name": "Berlin Events",
                "url": "https://example.com/events",
                "topic_ids": ["berlin-events"],
                "quality": 1.0,
            },
            {
                **payload["sources"][0],
                "id": "research",
                "name": "Research",
                "url": "https://example.com/research",
                "quality": 0.2,
            },
        ]
        self.sources.write_text(json.dumps(payload), encoding="utf-8")
        event_items = collected_items(12)
        research_items = collected_items(12)
        for item in research_items:
            item["title"] = f"Research {item['title']}"
        with patch("etl.collect.fetch", side_effect=[event_items, research_items]):
            collect_stage(self.connection, self.run_id, self.sources)
        normalize_stage(self.connection, self.run_id)
        deduplicate_stage(self.connection, self.run_id)

        self.assertEqual(rank_stage(self.connection, self.run_id), 10)
        self.assertEqual(
            self.connection.execute(
                "SELECT count(*) FROM run_candidates c "
                "JOIN normalized_items n ON n.id = c.normalized_item_id "
                "WHERE c.run_id = ? AND c.selected = 1 AND n.topic_ids_json LIKE '%berlin-events%'",
                (self.run_id,),
            ).fetchone()[0],
            2,
        )

    def test_feedback_follows_topics_instead_of_source_name(self):
        payload = json.loads(self.sources.read_text(encoding="utf-8"))
        payload["sources"][0]["name"] = "arXiv"
        payload["sources"][0]["topic_ids"] = ["creative-tooling"]
        self.sources.write_text(json.dumps(payload), encoding="utf-8")
        current = current_edition(self.connection)
        arxiv_story = next(item for item in current["items"] if item["source_name"] == "arXiv")
        creative_story = next(item for item in current["items"] if "creative-tooling" in item["topic_ids"])
        record_feedback(self.connection, arxiv_story["id"], "less_like_this", True)
        record_feedback(self.connection, creative_story["id"], "too_basic", True)
        with patch("etl.collect.fetch", return_value=collected_items()):
            collect_stage(self.connection, self.run_id, self.sources)
        normalize_stage(self.connection, self.run_id)
        deduplicate_stage(self.connection, self.run_id)
        rank_stage(self.connection, self.run_id)
        scores = {
            row[0]
            for row in self.connection.execute(
                "SELECT round(feedback_score, 3) FROM run_candidates WHERE run_id = ?",
                (self.run_id,),
            )
        }
        self.assertEqual(scores, {-0.175})

    def test_queued_deep_dive_contains_bounded_source_evidence(self):
        story = current_edition(self.connection)["items"][0]
        queue_deep_dive(self.connection, story["id"])
        request = queued_deep_dives(self.connection, limit=1)[0]
        self.assertEqual(request["evidence"]["source"]["url"], story["source_url"])
        self.assertEqual(request["evidence"]["source"]["content"], story["body"][:12000])
        self.assertNotIn("body", request)

    def test_queued_deep_dive_repairs_legacy_empty_evidence(self):
        story = current_edition(self.connection)["items"][0]
        self.connection.execute(
            "UPDATE edition_items SET evidence_json = '{}' WHERE story_id = ?",
            (story["id"],),
        )
        self.connection.commit()
        queue_deep_dive(self.connection, story["id"])
        request = queued_deep_dives(self.connection, limit=1)[0]
        self.assertEqual(request["evidence"]["source"]["content"], story["body"][:12000])
        self.assertEqual(request["evidence"]["citations"], story["citations"])

    def test_deep_dive_database_failure_reaches_job_boundary(self):
        story = current_edition(self.connection)["items"][0]
        queue_deep_dive(self.connection, story["id"])
        request = queued_deep_dives(self.connection, limit=1)[0]
        response = {
            "items": [],
            "deep_dives": [
                {
                    "story_id": story["id"],
                    "title": "Closer look",
                    "body": "A synthesis grounded in the stored evidence.",
                    "citations": story["citations"],
                }
            ],
        }
        with patch("etl.enrich.run_agent_json", return_value=(response, {"provider": "test"})):
            with self.assertRaises(sqlite3.IntegrityError):
                enrich_deep_dives(self.connection, "missing-run", [request], 1)


class ParsingAndValidationTests(unittest.TestCase):
    def test_agent_environment_does_not_inherit_application_secrets(self):
        with patch.dict(
            os.environ,
            {
                "HOME": "/tmp/home",
                "PATH": "/usr/bin",
                "VERSE_DEVICE_SECRET": "device-secret",
                "OPENAI_API_KEY": "provider-secret",
            },
            clear=True,
        ):
            environment = agent_environment()
        self.assertEqual(environment, {"HOME": "/tmp/home", "PATH": "/usr/bin"})

    def test_resolved_model_prefers_agent_protocol_output(self):
        self.assertEqual(resolved_model("provider: openai\nmodel: gpt-5.6-codex\n", None), "gpt-5.6-codex")
        self.assertEqual(resolved_model("", "configured-model"), "configured-model")

    def test_exclusions_ignore_instruction_language(self):
        topics = [
            {
                "id": "exclude-sponsored-content",
                "name": "Sponsored content",
                "kind": "exclusion",
                "description": "Exclude new tools and events when they are paid placements.",
            },
            {
                "id": "exclude-crypto-speculation",
                "name": "Crypto and NFT speculation",
                "kind": "exclusion",
                "description": "Exclude token markets.",
            },
        ]
        words = exclusion_words(topics)
        self.assertTrue({"sponsored", "crypto", "nft", "speculation"} <= words)
        self.assertTrue({"content", "new", "tools", "events"}.isdisjoint(words))

    def test_source_terms_match_words_and_phrases(self):
        self.assertTrue(term_present("an art installation", "art"))
        self.assertTrue(term_present("a video-to-audio model", "video-to-audio"))
        self.assertFalse(term_present("the artist is touring", "art"))
        self.assertFalse(term_present("speech recognitions", "speech recognition"))

    def test_feed_parsers_keep_source_evidence(self):
        json_items = parse_json_feed(
            json.dumps(
                {
                    "items": [
                        {
                            "id": "one",
                            "title": "JSON item",
                            "url": "https://example.com/one",
                            "date_published": "2026-07-12T08:00:00Z",
                            "content_text": "Body",
                        }
                    ]
                }
            ).encode()
        )
        atom_items = parse_xml_feed(
            b'<feed xmlns="http://www.w3.org/2005/Atom"><entry><id>two</id><title>Atom item</title><link href="https://example.com/two"/><updated>2026-07-13T09:00:00Z</updated><published>2026-07-12T09:00:00Z</published><summary>Body</summary></entry></feed>'
        )
        event_items = parse_json_ld_html(
            b'<html><script type="application/ld+json">{"@type":"ExhibitionEvent","id":"event","url":"https://example.com/event","name":"Media exhibition","description":"An installation.","startDate":"2026-07-12T10:00:00Z","location":{"name":"Berlin venue"}}</script></html>'
        )
        self.assertEqual(json_items[0]["url"], "https://example.com/one")
        self.assertEqual(atom_items[0]["external_id"], "two")
        self.assertEqual(atom_items[0]["published_at"], "2026-07-12T09:00:00Z")
        self.assertEqual(event_items[0]["content"], "An installation. Location: Berlin venue.")

    def test_url_normalization_removes_tracking_only(self):
        self.assertEqual(
            canonical_url("HTTPS://Example.COM/story/?b=2&utm_source=x&a=1#fragment"),
            "https://example.com/story?a=1&b=2",
        )
        self.assertEqual(
            canonical_url("http://www.arxiv.org/abs/2607.01234v3"),
            "https://arxiv.org/abs/2607.01234",
        )

    def test_validation_rejects_malformed_citations_and_short_editions(self):
        payload = json.loads((ROOT / "etl/seeds/first-edition.json").read_text(encoding="utf-8"))
        completed = complete_edition(payload)
        completed["items"][0]["citations"][0]["url"] = "javascript:alert(1)"
        with self.assertRaisesRegex(ValueError, "http or https"):
            validate_edition(completed)
        with self.assertRaisesRegex(ValueError, "between 8 and 12"):
            validate_edition(complete_edition({**payload, "items": payload["items"][:7]}))

    def test_validation_rejects_unknown_item_kinds(self):
        payload = complete_edition(json.loads((ROOT / "etl/seeds/first-edition.json").read_text(encoding="utf-8")))
        payload["items"][0]["kind"] = "advertisement"
        with self.assertRaisesRegex(ValueError, "kind is invalid"):
            validate_edition(payload)
        response = {
            "items": [
                {
                    "normalized_item_id": "one",
                    "title": "Title",
                    "summary": "Summary",
                    "body": "Body",
                    "why_selected": "Reason",
                    "kind": "advertisement",
                }
            ]
        }
        with self.assertRaisesRegex(ValueError, "kind is invalid"):
            validate_agent_items(response, [{"normalized_item_id": "one"}])

    def test_agent_deep_dives_reject_unstored_citations(self):
        request = {
            "story_id": "story",
            "citations": [
                {"title": "Stored", "url": "https://example.com/stored", "source_name": "Source", "published_at": None}
            ],
        }
        response = {
            "deep_dives": [
                {
                    "story_id": "story",
                    "title": "Deep",
                    "body": "Longer body",
                    "citations": [
                        {"title": "Invented", "url": "https://example.com/invented", "source_name": "Source", "published_at": None}
                    ],
                }
            ]
        }
        with self.assertRaisesRegex(ValueError, "stored source evidence"):
            validate_agent_deep_dives(response, [request])

    def test_agent_deep_dives_reject_non_objects_as_validation_errors(self):
        request = {"story_id": "story", "citations": []}
        with self.assertRaisesRegex(ValueError, "must be an object"):
            validate_agent_deep_dives({"deep_dives": [None]}, [request])


if __name__ == "__main__":
    unittest.main()
