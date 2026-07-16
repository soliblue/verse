import argparse
import json
import os
from pathlib import Path

from db.connection import connect
from db.connection import utc_now
from db.environment import load_environment
from db.migrations import migrate
from db.repository import publish_edition, replace_topics
from etl.content import content_root, load_edition, parse_preferences


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--edition", type=Path, default=Path("etl/seeds/first-edition.json"))
    parser.add_argument("--topics", type=Path, default=Path("etl/seeds/default-topics.json"))
    parser.add_argument("--skip-edition", action="store_true")
    parser.add_argument("--skip-topics", action="store_true")
    parser.add_argument("--replace-existing", action="store_true")
    parser.add_argument("--content-root", type=Path, default=content_root())
    return parser.parse_args()


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def seeded(connection, key: str) -> bool:
    return connection.execute("SELECT 1 FROM settings WHERE key = ?", (key,)).fetchone() is not None


def mark_seeded(connection, key: str) -> None:
    now = utc_now()
    with connection:
        connection.execute(
            "INSERT INTO settings (key, value, updated_at) VALUES (?, '1', ?) "
            "ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at",
            (key, now),
        )


def seed_database(
    connection,
    edition_payload: dict,
    topics_payload: dict,
    skip_edition: bool = False,
    skip_topics: bool = False,
    replace_existing: bool = False,
) -> dict[str, str]:
    status = {"topics": "skipped", "edition": "skipped"}
    if not skip_topics:
        has_topics = connection.execute("SELECT 1 FROM topics LIMIT 1").fetchone() is not None
        if replace_existing or (not seeded(connection, "default_topics_seeded") and not has_topics):
            replace_topics(connection, topics_payload)
            status["topics"] = "seeded"
        else:
            status["topics"] = "kept"
        mark_seeded(connection, "default_topics_seeded")
    if not skip_edition:
        has_editions = connection.execute("SELECT 1 FROM editions LIMIT 1").fetchone() is not None
        if replace_existing or (not seeded(connection, "first_edition_seeded") and not has_editions):
            publish_edition(connection, edition_payload)
            status["edition"] = "seeded"
        else:
            status["edition"] = "kept"
        mark_seeded(connection, "first_edition_seeded")
    return status


def main() -> int:
    os.umask(0o077)
    load_environment()
    args = parse_args()
    connection = connect()
    migrate(connection)
    edition_payload = load(args.edition)
    topics_payload = load(args.topics)
    markdown_editions = sorted((args.content_root / "editions").glob("*/edition.md"))
    markdown_preferences = args.content_root / "preferences.md"
    if markdown_editions:
        edition_payload = load_edition(markdown_editions[-1], os.environ.get("VERSE_PUBLIC_BASE_URL") or None)[0]
    if markdown_preferences.is_file():
        topics_payload = parse_preferences(markdown_preferences)
    status = seed_database(
        connection,
        edition_payload,
        topics_payload,
        args.skip_edition,
        args.skip_topics,
        args.replace_existing,
    )
    connection.close()
    print(f"topics={status['topics']} edition={status['edition']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
