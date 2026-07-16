import json
import sqlite3
from copy import deepcopy
from pathlib import Path
from urllib.parse import quote

from db.connection import json_text, transaction, utc_now
from db.editions import publish_edition
from db.state import materialize_story_state
from db.topics import replace_topics
from etl.content import load_deep_dive, load_edition, parse_preferences


def relative_path(path: Path, root: Path) -> str:
    return path.resolve().relative_to(root.resolve()).as_posix()


def infer_topic_relations(connection: sqlite3.Connection, edition_id: str, story_id: str, topic_ids: list[str]) -> None:
    if not topic_ids:
        return
    placeholders = ",".join("?" for _ in topic_ids)
    rows = connection.execute(
        "SELECT t.story_id, count(DISTINCT t.topic_id) AS shared "
        "FROM story_topics t JOIN edition_items i ON i.story_id = t.story_id "
        f"WHERE t.topic_id IN ({placeholders}) AND t.story_id <> ? AND i.edition_id <> ? "
        "GROUP BY t.story_id ORDER BY shared DESC, max(i.position), t.story_id LIMIT 3",
        (*topic_ids, story_id, edition_id),
    ).fetchall()
    now = utc_now()
    for row in rows:
        target_topics = {
            value[0]
            for value in connection.execute("SELECT topic_id FROM story_topics WHERE story_id = ?", (row["story_id"],))
        }
        score = row["shared"] / len(set(topic_ids) | target_topics)
        connection.execute(
            "INSERT INTO story_relations "
            "(source_story_id, target_story_id, relation, score, evidence, created_at, updated_at) "
            "VALUES (?, ?, 'shared_topic', ?, ?, ?, ?) "
            "ON CONFLICT(source_story_id, target_story_id, relation) DO UPDATE SET "
            "score = excluded.score, evidence = excluded.evidence, updated_at = excluded.updated_at",
            (story_id, row["story_id"], score, ", ".join(sorted(set(topic_ids) & target_topics)), now, now),
        )


def index_edition(connection: sqlite3.Connection, payload: dict, index: dict, root: Path) -> None:
    now = utc_now()
    with transaction(connection, immediate=True):
        connection.execute(
            "INSERT INTO edition_documents (edition_id, markdown_path, content_sha256, indexed_at) VALUES (?, ?, ?, ?) "
            "ON CONFLICT(edition_id) DO UPDATE SET markdown_path = excluded.markdown_path, "
            "content_sha256 = excluded.content_sha256, indexed_at = excluded.indexed_at",
            (payload["id"], relative_path(index["edition_path"], root), index["edition_sha256"], now),
        )
        indexed = {story["story_id"]: story for story in index["stories"]}
        for item in payload["items"]:
            story = indexed[item["id"]]
            connection.execute(
                "INSERT INTO story_documents "
                "(story_id, markdown_path, content_sha256, cover_path, cover_prompt, cover_model, "
                "cover_width, cover_height, cover_is_fallback, indexed_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?) "
                "ON CONFLICT(story_id) DO UPDATE SET markdown_path = excluded.markdown_path, "
                "content_sha256 = excluded.content_sha256, cover_path = excluded.cover_path, "
                "cover_prompt = excluded.cover_prompt, cover_model = excluded.cover_model, "
                "cover_width = excluded.cover_width, cover_height = excluded.cover_height, "
                "cover_is_fallback = excluded.cover_is_fallback, indexed_at = excluded.indexed_at",
                (
                    item["id"],
                    relative_path(story["path"], root),
                    story["sha256"],
                    story["cover_path"],
                    story["cover_prompt"],
                    story["cover_model"],
                    story["cover_width"],
                    story["cover_height"],
                    int(story["cover_is_fallback"]),
                    now,
                ),
            )
            connection.execute("DELETE FROM story_topics WHERE story_id = ?", (item["id"],))
            connection.executemany(
                "INSERT INTO story_topics (story_id, topic_id) VALUES (?, ?)",
                [(item["id"], topic_id) for topic_id in item["topic_ids"]],
            )
            connection.execute(
                "DELETE FROM story_relations WHERE source_story_id = ? AND relation IN ('related', 'shared_topic')",
                (item["id"],),
            )
            for target in item.get("related_story_ids", []):
                if connection.execute("SELECT 1 FROM stories WHERE id = ?", (target,)).fetchone() is None:
                    raise ValueError(f"related story {target} does not exist")
                connection.execute(
                    "INSERT INTO story_relations "
                    "(source_story_id, target_story_id, relation, score, evidence, created_at, updated_at) "
                    "VALUES (?, ?, 'related', 1, 'markdown', ?, ?)",
                    (item["id"], target, now, now),
                )
            connection.execute("DELETE FROM story_events WHERE story_id = ?", (item["id"],))
            connection.executemany(
                "INSERT INTO story_events (story_id, occurrence_id) VALUES (?, ?)",
                [(item["id"], occurrence_id) for occurrence_id in item.get("related_event_ids", [])],
            )
        for item in payload["items"]:
            infer_topic_relations(connection, payload["id"], item["id"], item["topic_ids"])


def import_deep_dive(connection: sqlite3.Connection, path: Path) -> None:
    story_id, payload, provenance = load_deep_dive(path)
    rows = connection.execute(
        "SELECT e.payload_json FROM editions e JOIN edition_items i ON i.edition_id = e.id WHERE i.story_id = ?",
        (story_id,),
    ).fetchall()
    if not rows:
        raise ValueError(f"deep dive story {story_id} does not exist")
    allowed = {
        json_text(citation)
        for row in rows
        for item in json.loads(row["payload_json"])["items"]
        if item["id"] == story_id
        for citation in item["citations"]
    }
    if any(json_text(citation) not in allowed for citation in payload["citations"]):
        raise ValueError(f"deep dive {story_id} contains a citation outside its story evidence")
    now = utc_now()
    with transaction(connection, immediate=True):
        connection.execute(
            "INSERT INTO deep_dives "
            "(story_id, status, requested_at, title, body, citations_json, model_provenance_json, updated_at) "
            "VALUES (?, 'ready', ?, ?, ?, ?, ?, ?) ON CONFLICT(story_id) DO UPDATE SET "
            "status = 'ready', title = excluded.title, body = excluded.body, citations_json = excluded.citations_json, "
            "model_provenance_json = excluded.model_provenance_json, updated_at = excluded.updated_at",
            (
                story_id,
                provenance.get("completed_at") or now,
                payload["title"],
                payload["body"],
                json_text(payload["citations"]),
                json_text(provenance),
                now,
            ),
        )
        materialize_story_state(connection, story_id)


def sync_content(connection: sqlite3.Connection, root: Path, public_base_url: str | None = None) -> dict:
    status = {"preferences": 0, "editions": 0, "stories": 0, "deep_dives": 0}
    preferences = root / "preferences.md"
    if preferences.is_file():
        replace_topics(connection, parse_preferences(preferences))
        status["preferences"] = 1
    for path in sorted((root / "editions").glob("*/edition.md")) if (root / "editions").is_dir() else []:
        payload, index = load_edition(path, public_base_url)
        publish_edition(connection, payload)
        index_edition(connection, payload, index, root)
        status["editions"] += 1
        status["stories"] += len(payload["items"])
    for path in sorted((root / "deep-dives" / "ready").glob("*.md")) if (root / "deep-dives" / "ready").is_dir() else []:
        import_deep_dive(connection, path)
        status["deep_dives"] += 1
    latest = connection.execute("SELECT id FROM editions ORDER BY edition_date DESC, generated_at DESC LIMIT 1").fetchone()
    if latest is not None:
        connection.execute(
            "INSERT INTO settings (key, value, updated_at) VALUES ('current_edition_id', ?, ?) "
            "ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at",
            (latest["id"], utc_now()),
        )
        connection.commit()
    return status


def related_stories(connection: sqlite3.Connection, story_id: str, limit: int = 6) -> dict:
    if connection.execute("SELECT 1 FROM stories WHERE id = ?", (story_id,)).fetchone() is None:
        raise LookupError("story not found")
    rows = connection.execute(
        "SELECT source_story_id, target_story_id, relation, score FROM story_relations "
        "WHERE source_story_id = ? OR target_story_id = ? ORDER BY score DESC, updated_at DESC LIMIT ?",
        (story_id, story_id, limit),
    ).fetchall()
    stories = []
    seen = set()
    for row in rows:
        target = row["target_story_id"] if row["source_story_id"] == story_id else row["source_story_id"]
        if target in seen:
            continue
        seen.add(target)
        editions = connection.execute(
            "SELECT e.payload_json FROM editions e JOIN edition_items i ON i.edition_id = e.id "
            "WHERE i.story_id = ? ORDER BY e.edition_date DESC, e.generated_at DESC LIMIT 1",
            (target,),
        ).fetchone()
        if editions is None:
            continue
        item = next(value for value in json.loads(editions["payload_json"])["items"] if value["id"] == target)
        stories.append({"relation": row["relation"], "score": row["score"], "item": item})
    return {"story_id": story_id, "stories": stories}


def hydrate_cover_urls(connection: sqlite3.Connection, payload: dict, public_base_url: str | None) -> dict:
    if public_base_url is None:
        return payload
    hydrated = deepcopy(payload)
    covers = {
        row["story_id"]: row["cover_path"]
        for row in connection.execute(
            "SELECT d.story_id, d.cover_path FROM story_documents d JOIN edition_items i ON i.story_id = d.story_id "
            "WHERE i.edition_id = ? AND d.cover_path IS NOT NULL",
            (payload["id"],),
        )
    }
    for item in hydrated["items"]:
        cover = covers.get(item["id"])
        if cover is None:
            continue
        parts = Path(cover).parts
        if len(parts) != 4 or parts[0] != "editions" or parts[2] != "assets":
            continue
        encoded = "/".join(quote(part, safe="") for part in parts[1:])
        item["image_url"] = f"{public_base_url.rstrip('/')}/v1/assets/{encoded}"
    return hydrated
