import json
import os
import re
import sqlite3
from datetime import date
from pathlib import Path

from db.connection import transaction, utc_now
from db.repository import edition, publish_edition, store_deep_dive
from etl.validation import complete_edition, validate_edition


def edition_title(value: date) -> str:
    return f"Verse for {value.strftime('%A')}, {value.day} {value.strftime('%B')}"


def write_artifact(run_id: str, payload: dict) -> Path:
    directory = Path(os.environ.get("VERSE_RUNS_DIR", "runs")) / re.sub(r"[^a-zA-Z0-9._-]", "-", run_id)
    directory.mkdir(parents=True, exist_ok=True)
    temporary = directory / "edition.json.tmp"
    destination = directory / "edition.json"
    temporary.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(destination)
    return destination


def write_stage(connection: sqlite3.Connection, run_id: str) -> int:
    run = connection.execute("SELECT edition_date FROM etl_runs WHERE id = ?", (run_id,)).fetchone()
    if run is None:
        raise ValueError("run does not exist")
    rows = connection.execute(
        "SELECT story_id, position, payload_json, evidence_json, model_provenance_json FROM draft_stories WHERE run_id = ? ORDER BY position",
        (run_id,),
    ).fetchall()
    edition_date = date.fromisoformat(run["edition_date"])
    payload = complete_edition(
        {
            "id": f"edition-{run['edition_date']}",
            "date": run["edition_date"],
            "title": edition_title(edition_date),
            "dek": f"{len(rows)} selected signals for a finite morning read.",
            "generated_at": utc_now(),
            "items": [json.loads(row["payload_json"]) for row in rows],
        }
    )
    validate_edition(payload)
    evidence = {row["story_id"]: json.loads(row["evidence_json"]) for row in rows}
    provenance = {row["story_id"]: json.loads(row["model_provenance_json"]) for row in rows}
    deep_dives = connection.execute(
        "SELECT story_id, payload_json, model_provenance_json FROM run_deep_dives WHERE run_id = ?", (run_id,)
    ).fetchall()
    with transaction(connection, immediate=True):
        publish_edition(connection, payload, evidence, provenance)
        for row in deep_dives:
            store_deep_dive(
                connection,
                row["story_id"],
                json.loads(row["payload_json"]),
                json.loads(row["model_provenance_json"]),
            )
        published = edition(connection, payload["id"])
        if published is None:
            raise RuntimeError("published edition could not be materialized")
        validate_edition(published)
        write_artifact(run_id, published)
    return len(rows)
