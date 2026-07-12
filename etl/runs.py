import sqlite3
from collections.abc import Callable
from datetime import date

from db.connection import utc_now


STAGES = ("collect", "normalize", "deduplicate", "rank", "enrich", "write")


def start_run(connection: sqlite3.Connection, edition_date: str, run_id: str | None = None) -> str:
    date.fromisoformat(edition_date)
    resolved = run_id or f"nightjar-{edition_date}"
    now = utc_now()
    with connection:
        connection.execute("BEGIN IMMEDIATE")
        row = connection.execute("SELECT edition_date FROM etl_runs WHERE id = ?", (resolved,)).fetchone()
        if row is not None and row["edition_date"] != edition_date:
            raise ValueError("run id already belongs to another edition date")
        connection.execute(
            "INSERT INTO etl_runs (id, edition_date, status, current_stage, started_at, updated_at, completed_at, error) VALUES (?, ?, 'running', NULL, ?, ?, NULL, NULL) ON CONFLICT(id) DO UPDATE SET status = CASE WHEN etl_runs.status = 'completed' THEN etl_runs.status ELSE 'running' END, updated_at = excluded.updated_at, error = NULL",
            (resolved, edition_date, now, now),
        )
    return resolved


def require_run(connection: sqlite3.Connection, run_id: str) -> sqlite3.Row:
    row = connection.execute("SELECT * FROM etl_runs WHERE id = ?", (run_id,)).fetchone()
    if row is None:
        raise ValueError("run does not exist")
    return row


def reset_from_stage(connection: sqlite3.Connection, run_id: str, stage: str) -> None:
    index = STAGES.index(stage)
    with connection:
        connection.execute("BEGIN IMMEDIATE")
        connection.executemany(
            "DELETE FROM etl_stage_results WHERE run_id = ? AND stage = ?", [(run_id, name) for name in STAGES[index:]]
        )
        if index <= STAGES.index("collect"):
            connection.execute("DELETE FROM etl_source_results WHERE run_id = ?", (run_id,))
            connection.execute("DELETE FROM run_source_items WHERE run_id = ?", (run_id,))
        if index <= STAGES.index("normalize"):
            connection.execute("DELETE FROM run_normalized_items WHERE run_id = ?", (run_id,))
        if index <= STAGES.index("deduplicate"):
            connection.execute("DELETE FROM run_candidates WHERE run_id = ?", (run_id,))
        if index <= STAGES.index("enrich"):
            connection.execute("DELETE FROM draft_stories WHERE run_id = ?", (run_id,))
            connection.execute("DELETE FROM run_deep_dives WHERE run_id = ?", (run_id,))
        connection.execute(
            "UPDATE etl_runs SET status = 'running', current_stage = NULL, completed_at = NULL, error = NULL, updated_at = ? WHERE id = ?",
            (utc_now(), run_id),
        )


def run_stage(
    connection: sqlite3.Connection,
    run_id: str,
    stage: str,
    action: Callable[[], int],
    force: bool = False,
) -> int:
    require_run(connection, run_id)
    existing = connection.execute(
        "SELECT status, row_count FROM etl_stage_results WHERE run_id = ? AND stage = ?", (run_id, stage)
    ).fetchone()
    if existing is not None and existing["status"] == "completed" and not force:
        return existing["row_count"]
    if force:
        reset_from_stage(connection, run_id, stage)
    index = STAGES.index(stage)
    if index:
        previous = connection.execute(
            "SELECT status FROM etl_stage_results WHERE run_id = ? AND stage = ?", (run_id, STAGES[index - 1])
        ).fetchone()
        if previous is None or previous["status"] != "completed":
            raise RuntimeError(f"{STAGES[index - 1]} must complete before {stage}")
    started_at = utc_now()
    with connection:
        connection.execute(
            "INSERT INTO etl_stage_results (run_id, stage, status, row_count, started_at, completed_at, error) VALUES (?, ?, 'running', NULL, ?, NULL, NULL) ON CONFLICT(run_id, stage) DO UPDATE SET status = 'running', row_count = NULL, started_at = excluded.started_at, completed_at = NULL, error = NULL",
            (run_id, stage, started_at),
        )
        connection.execute(
            "UPDATE etl_runs SET status = 'running', current_stage = ?, updated_at = ?, completed_at = NULL, error = NULL WHERE id = ?",
            (stage, started_at, run_id),
        )
    try:
        row_count = action()
    except Exception as error:
        with connection:
            connection.execute(
                "UPDATE etl_stage_results SET status = 'failed', completed_at = ?, error = ? WHERE run_id = ? AND stage = ?",
                (utc_now(), str(error)[:4000], run_id, stage),
            )
            connection.execute(
                "UPDATE etl_runs SET status = 'failed', updated_at = ?, error = ? WHERE id = ?",
                (utc_now(), str(error)[:4000], run_id),
            )
        raise
    completed_at = utc_now()
    with connection:
        connection.execute(
            "UPDATE etl_stage_results SET status = 'completed', row_count = ?, completed_at = ?, error = NULL WHERE run_id = ? AND stage = ?",
            (row_count, completed_at, run_id, stage),
        )
        connection.execute(
            "UPDATE etl_runs SET updated_at = ?, status = ?, completed_at = ?, error = NULL WHERE id = ?",
            (
                completed_at,
                "completed" if stage == "write" else "running",
                completed_at if stage == "write" else None,
                run_id,
            ),
        )
    return row_count
