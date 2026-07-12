import json
import sqlite3

from db.connection import json_text, transaction, utc_now
from db.state import deep_dive_state, hydrate_item_state
from etl.validation import complete_edition, validate_edition


def item_evidence(item: dict) -> dict:
    return {
        "source": {
            "title": item["title"],
            "url": item["source_url"],
            "source_name": item["source_name"],
            "published_at": item["published_at"],
            "content": item["body"],
        },
        "citations": item["citations"],
    }


def publish_edition(
    connection: sqlite3.Connection,
    payload: dict,
    evidence: dict[str, object] | None = None,
    provenance: dict[str, object] | None = None,
) -> dict:
    completed = complete_edition(payload)
    validate_edition(completed)
    evidence = evidence or {}
    provenance = provenance or {}
    now = utc_now()
    with transaction(connection, immediate=True):
        for item in completed["items"]:
            connection.execute(
                "INSERT INTO stories (id, source_name, source_url, published_at, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET source_name = excluded.source_name, source_url = excluded.source_url, published_at = excluded.published_at, updated_at = excluded.updated_at",
                (item["id"], item["source_name"], item["source_url"], item["published_at"], now, now),
            )
            supplied = item["deep_dive"]
            if supplied["status"] != "not_requested" and deep_dive_state(connection, item["id"])["status"] == "not_requested":
                connection.execute(
                    "INSERT INTO deep_dives (story_id, status, requested_at, title, body, citations_json, model_provenance_json, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                    (
                        item["id"],
                        supplied["status"],
                        supplied["requested_at"] or now,
                        supplied["title"],
                        supplied["body"],
                        json_text(supplied["citations"]),
                        json_text(provenance.get(item["id"], {})),
                        now,
                    ),
                )
        completed["items"] = [hydrate_item_state(connection, item) for item in completed["items"]]
        validate_edition(completed)
        connection.execute("DELETE FROM editions WHERE edition_date = ? AND id <> ?", (completed["date"], completed["id"]))
        connection.execute(
            "INSERT INTO editions (id, edition_date, title, dek, generated_at, item_count, payload_json, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET edition_date = excluded.edition_date, title = excluded.title, dek = excluded.dek, generated_at = excluded.generated_at, item_count = excluded.item_count, payload_json = excluded.payload_json, updated_at = excluded.updated_at",
            (
                completed["id"],
                completed["date"],
                completed["title"],
                completed["dek"],
                completed["generated_at"],
                len(completed["items"]),
                json_text(completed),
                now,
                now,
            ),
        )
        connection.execute("DELETE FROM edition_items WHERE edition_id = ?", (completed["id"],))
        for item in completed["items"]:
            connection.execute(
                "INSERT INTO edition_items (edition_id, story_id, position, evidence_json, model_provenance_json) VALUES (?, ?, ?, ?, ?)",
                (
                    completed["id"],
                    item["id"],
                    item["position"],
                    json_text(evidence.get(item["id"], item_evidence(item))),
                    json_text(
                        provenance.get(
                            item["id"],
                            {
                                "provider": "curated_seed",
                                "prompt_version": None,
                                "researched_at": completed["generated_at"],
                            },
                        )
                    ),
                ),
            )
        connection.execute(
            "INSERT INTO settings (key, value, updated_at) VALUES ('current_edition_id', ?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at",
            (completed["id"], now),
        )
    return completed


def current_edition(connection: sqlite3.Connection) -> dict | None:
    row = connection.execute(
        "SELECT e.payload_json FROM editions e JOIN settings s ON s.key = 'current_edition_id' AND s.value = e.id"
    ).fetchone()
    return None if row is None else json.loads(row["payload_json"])


def edition(connection: sqlite3.Connection, edition_id: str) -> dict | None:
    row = connection.execute("SELECT payload_json FROM editions WHERE id = ?", (edition_id,)).fetchone()
    return None if row is None else json.loads(row["payload_json"])


def edition_summaries(connection: sqlite3.Connection) -> dict:
    rows = connection.execute(
        "SELECT id, edition_date, title, dek, generated_at, item_count FROM editions ORDER BY edition_date DESC, generated_at DESC"
    )
    return {
        "editions": [
            {
                "id": row["id"],
                "date": row["edition_date"],
                "title": row["title"],
                "dek": row["dek"],
                "generated_at": row["generated_at"],
                "item_count": row["item_count"],
            }
            for row in rows
        ]
    }
