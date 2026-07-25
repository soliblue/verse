import sqlite3
import unittest

from db.migrations import migrate
from db.repository import current_edition, edition_summaries, publish_edition
from scripts.reset_article_editions import reset_article_editions


class ResetArticleEditionsTests(unittest.TestCase):
    def setUp(self) -> None:
        self.connection = sqlite3.connect(":memory:")
        self.connection.row_factory = sqlite3.Row
        migrate(self.connection)

    def tearDown(self) -> None:
        self.connection.close()

    def test_keeps_story_registry_for_deduplication(self) -> None:
        payload = {
            "id": "edition-2026-07-25",
            "date": "2026-07-25",
            "title": "Fresh",
            "dek": "Fresh edition",
            "generated_at": "2026-07-25T06:00:00Z",
            "items": [
                {
                    "id": f"story-{index}",
                    "position": index,
                    "kind": "paper",
                    "topic_ids": ["test"],
                    "title": f"Story {index}",
                    "summary": "Summary",
                    "body": "Body",
                    "why_selected": "Reason",
                    "source_name": "Source",
                    "source_url": f"https://example.com/{index}",
                    "published_at": "2026-07-24T00:00:00Z",
                    "reading_minutes": 1,
                    "citations": [
                        {
                            "title": "Source",
                            "url": f"https://example.com/{index}",
                            "source_name": "Source",
                            "published_at": "2026-07-24T00:00:00Z",
                        }
                    ],
                }
                for index in range(1, 9)
            ],
        }
        publish_edition(self.connection, payload)
        self.assertEqual(reset_article_editions(self.connection), 1)
        self.assertIsNone(current_edition(self.connection))
        self.assertEqual(edition_summaries(self.connection), {"editions": []})
        self.assertEqual(self.connection.execute("SELECT count(*) FROM stories").fetchone()[0], 8)


if __name__ == "__main__":
    unittest.main()
