import json
import sqlite3
from copy import deepcopy

from db.connection import json_text, transaction, utc_now
from etl.validation import require_text, validate_citations, validate_edition


DEFAULT_FEEDBACK = {"saved": False, "seen": False, "preference": None, "updated_at": None}
DEFAULT_DEEP_DIVE = {"status": "not_requested", "requested_at": None, "title": None, "body": None, "citations": []}


def feedback_state(connection: sqlite3.Connection, story_id: str) -> dict:
    row = connection.execute(
        "SELECT saved, seen, preference, updated_at FROM feedback_state WHERE story_id = ?", (story_id,)
    ).fetchone()
    return deepcopy(DEFAULT_FEEDBACK) if row is None else {
        "saved": bool(row["saved"]),
        "seen": bool(row["seen"]),
        "preference": row["preference"],
        "updated_at": row["updated_at"],
    }


def deep_dive_state(connection: sqlite3.Connection, story_id: str) -> dict:
    row = connection.execute(
        "SELECT status, requested_at, title, body, citations_json FROM deep_dives WHERE story_id = ?", (story_id,)
    ).fetchone()
    return deepcopy(DEFAULT_DEEP_DIVE) if row is None else {
        "status": row["status"],
        "requested_at": row["requested_at"],
        "title": row["title"],
        "body": row["body"],
        "citations": json.loads(row["citations_json"]),
    }


def hydrate_item_state(connection: sqlite3.Connection, item: dict) -> dict:
    hydrated = deepcopy(item)
    deep_dive = deep_dive_state(connection, item["id"])
    known_citations = {json_text(citation) for citation in hydrated["citations"]}
    for citation in deep_dive["citations"]:
        if json_text(citation) not in known_citations:
            hydrated["citations"].append(citation)
            known_citations.add(json_text(citation))
    hydrated["feedback"] = feedback_state(connection, item["id"])
    hydrated["deep_dive"] = deep_dive
    return hydrated


def materialize_story_state(connection: sqlite3.Connection, story_id: str) -> None:
    rows = connection.execute(
        "SELECT e.id, e.payload_json FROM editions e JOIN edition_items i ON i.edition_id = e.id WHERE i.story_id = ?",
        (story_id,),
    ).fetchall()
    for row in rows:
        payload = json.loads(row["payload_json"])
        payload["items"] = [hydrate_item_state(connection, item) if item["id"] == story_id else item for item in payload["items"]]
        validate_edition(payload)
        connection.execute(
            "UPDATE editions SET payload_json = ?, updated_at = ? WHERE id = ?", (json_text(payload), utc_now(), row["id"])
        )


def record_feedback(connection: sqlite3.Connection, story_id: str, kind: str, value: bool) -> dict:
    if kind not in {"saved", "seen", "more_like_this", "less_like_this", "too_basic"}:
        raise ValueError("feedback kind is invalid")
    if not isinstance(value, bool):
        raise ValueError("feedback value must be a boolean")
    with transaction(connection, immediate=True):
        if connection.execute("SELECT 1 FROM stories WHERE id = ?", (story_id,)).fetchone() is None:
            raise LookupError("story not found")
        state = feedback_state(connection, story_id)
        if kind in {"saved", "seen"}:
            state[kind] = value
        else:
            state["preference"] = kind if value else (None if state["preference"] == kind else state["preference"])
        state["updated_at"] = utc_now()
        connection.execute(
            "INSERT INTO feedback_state (story_id, saved, seen, preference, updated_at) VALUES (?, ?, ?, ?, ?) ON CONFLICT(story_id) DO UPDATE SET saved = excluded.saved, seen = excluded.seen, preference = excluded.preference, updated_at = excluded.updated_at",
            (story_id, int(state["saved"]), int(state["seen"]), state["preference"], state["updated_at"]),
        )
        connection.execute(
            "INSERT INTO feedback_events (story_id, kind, value, created_at) VALUES (?, ?, ?, ?)",
            (story_id, kind, int(value), state["updated_at"]),
        )
        materialize_story_state(connection, story_id)
    return state


def queue_deep_dive(connection: sqlite3.Connection, story_id: str) -> dict:
    with transaction(connection, immediate=True):
        if connection.execute("SELECT 1 FROM stories WHERE id = ?", (story_id,)).fetchone() is None:
            raise LookupError("story not found")
        current = deep_dive_state(connection, story_id)
        if current["status"] in {"queued", "ready"}:
            return current
        now = utc_now()
        connection.execute(
            "INSERT INTO deep_dives (story_id, status, requested_at, title, body, citations_json, model_provenance_json, updated_at) VALUES (?, 'queued', ?, NULL, NULL, '[]', '{}', ?) ON CONFLICT(story_id) DO UPDATE SET status = 'queued', requested_at = excluded.requested_at, title = NULL, body = NULL, citations_json = '[]', model_provenance_json = '{}', updated_at = excluded.updated_at",
            (story_id, now, now),
        )
        materialize_story_state(connection, story_id)
    return deep_dive_state(connection, story_id)


def store_deep_dive(connection: sqlite3.Connection, story_id: str, payload: dict, provenance: dict) -> None:
    require_text(payload.get("title"), "deep_dive.title")
    require_text(payload.get("body"), "deep_dive.body")
    validate_citations(payload.get("citations"), "deep_dive.citations")
    rows = connection.execute(
        "SELECT e.payload_json FROM editions e JOIN edition_items i ON i.edition_id = e.id "
        "WHERE i.story_id = ? ORDER BY e.edition_date DESC",
        (story_id,),
    ).fetchall()
    if not rows:
        raise LookupError("story not found in an edition")
    allowed = {
        json_text(citation)
        for row in rows
        for item in json.loads(row["payload_json"])["items"]
        if item["id"] == story_id
        for citation in item["citations"]
    }
    if any(json_text(citation) not in allowed for citation in payload["citations"]):
        raise ValueError("deep-dive citations must come from stored source evidence")
    now = utc_now()
    connection.execute(
        "UPDATE deep_dives SET status = 'ready', title = ?, body = ?, citations_json = ?, "
        "model_provenance_json = ?, updated_at = ? WHERE story_id = ? AND status = 'queued'",
        (payload["title"], payload["body"], json_text(payload["citations"]), json_text(provenance), now, story_id),
    )
    materialize_story_state(connection, story_id)


def fail_deep_dive(connection: sqlite3.Connection, story_id: str, error: Exception) -> None:
    now = utc_now()
    with transaction(connection, immediate=True):
        connection.execute(
            "UPDATE deep_dives SET status = 'failed', model_provenance_json = ?, updated_at = ? "
            "WHERE story_id = ? AND status = 'queued'",
            (json_text({"provider": "agent", "error": str(error)[:4000], "completed_at": now}), now, story_id),
        )
        materialize_story_state(connection, story_id)
