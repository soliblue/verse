import argparse
import hashlib
import json
import shutil
import sqlite3
import uuid
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

from etl.content import load_deep_dive, load_edition, parse_document, parse_preferences, render_document
from etl.covers import prepare_cover
from etl.explore import build_explore, write_explore


WORKSPACE_FILES = {"AGENTS.md", "content", "nightjar-input.json"}


def input_snapshot(database: Path | None) -> dict:
    empty = {"story_feedback": [], "event_feedback": [], "venue_feedback": [], "queued_deep_dives": []}
    if database is None or not database.is_file():
        return empty
    connection = sqlite3.connect(f"file:{database}?mode=ro", uri=True)
    connection.row_factory = sqlite3.Row
    tables = {row[0] for row in connection.execute("SELECT name FROM sqlite_master WHERE type = 'table'")}
    result = dict(empty)
    if "feedback_state" in tables:
        result["story_feedback"] = [
            dict(row)
            for row in connection.execute(
                "SELECT story_id, saved, seen, preference FROM feedback_state "
                "WHERE saved = 1 OR seen = 1 OR preference IS NOT NULL ORDER BY updated_at DESC"
            )
        ]
    if "event_feedback_state" in tables:
        result["event_feedback"] = [
            {
                "event_id": row["event_id"],
                "occurrence_id": row["occurrence_id"],
                "signals": json.loads(row["signals_json"]),
            }
            for row in connection.execute(
                "SELECT event_id, occurrence_id, signals_json FROM event_feedback_state ORDER BY updated_at DESC"
            )
        ]
    if "venue_feedback_state" in tables:
        result["venue_feedback"] = [
            dict(row)
            for row in connection.execute(
                "SELECT venue_id, more_from_here, muted FROM venue_feedback_state ORDER BY updated_at DESC"
            )
        ]
    if "deep_dives" in tables:
        result["queued_deep_dives"] = [
            row["story_id"]
            for row in connection.execute(
                "SELECT story_id FROM deep_dives WHERE status = 'queued' ORDER BY requested_at"
            )
        ]
    connection.close()
    return result


def workspace_instructions() -> str:
    return """# Nightjar content workspace

This isolated workspace contains only Verse editorial content and a feedback snapshot.

- Read `content/preferences.md`, `nightjar-input.json`, recent editions, events, and places.
- Write only below `content/`.
- Never read or write outside this workspace.
- Do not use Git, deploy, install packages, access credentials, or edit application or server source code.
- Keep Markdown as the editable content source and generated JSON as disposable output.
- Use primary official sources and retain evidence URLs, publication dates, and checked timestamps.
- Never invent citations, facts, availability, prices, dates, or image provenance.
"""


def prepare_workspace(root: Path, workspace: Path, database: Path | None) -> None:
    if workspace.exists():
        raise FileExistsError(workspace)
    workspace.mkdir(parents=True)
    shutil.copytree(root / "content", workspace / "content")
    (workspace / "AGENTS.md").write_text(workspace_instructions(), encoding="utf-8")
    (workspace / "nightjar-input.json").write_text(
        json.dumps(input_snapshot(database), ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def file_hashes(root: Path) -> dict[str, str]:
    if not root.is_dir():
        return {}
    return {
        path.relative_to(root).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in sorted(root.rglob("*"))
        if path.is_file()
    }


def protect_existing_content(root: Path, candidate: Path, run_date: str) -> None:
    if (root / "preferences.md").read_bytes() != (candidate / "preferences.md").read_bytes():
        raise ValueError("Nightjar must not edit preferences.md")
    existing = file_hashes(root / "editions")
    proposed = file_hashes(candidate / "editions")
    protected = {path: digest for path, digest in existing.items() if not path.startswith(f"{run_date}/")}
    for path, digest in protected.items():
        if proposed.get(path) != digest:
            raise ValueError(f"Nightjar changed an earlier edition: {path}")


def valid_cover(path: Path, metadata: dict, story_id: str) -> bool:
    if not path.is_file() or path.read_bytes()[:8] != b"\x89PNG\r\n\x1a\n":
        return False
    sidecar = path.with_suffix(".cover.json")
    if not sidecar.is_file():
        return False
    try:
        provenance = json.loads(sidecar.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return False
    return (
        provenance.get("story_id") == story_id
        and provenance.get("prompt") == metadata.get("cover_prompt")
        and provenance.get("model") == metadata.get("cover_model")
        and provenance.get("width") == metadata.get("cover_width")
        and provenance.get("height") == metadata.get("cover_height")
        and provenance.get("is_fallback") == bool(metadata.get("cover_fallback"))
    )


def ensure_target_covers(content: Path, run_date: str) -> None:
    edition_path = content / "editions" / run_date / "edition.md"
    edition_metadata, _ = parse_document(edition_path)
    filenames = edition_metadata.get("stories")
    if not isinstance(filenames, list):
        raise ValueError("target edition stories must be a list")
    for filename in filenames:
        story_path = edition_path.parent / filename
        metadata, body = parse_document(story_path)
        story_id = metadata.get("id")
        lines = body.splitlines()
        if not isinstance(story_id, str) or not lines or not lines[0].startswith("# "):
            raise ValueError(f"invalid story document: {filename}")
        cover_value = metadata.get("cover")
        cover_path = story_path.parent / cover_value if isinstance(cover_value, str) else Path()
        if isinstance(cover_value, str) and valid_cover(cover_path, metadata, story_id):
            continue
        cover = prepare_cover(
            story_path.parent / "assets",
            {
                "id": story_id,
                "title": lines[0][2:].strip(),
                "kind": metadata.get("kind") or "story",
                "topic_ids": metadata.get("topic_ids") or [],
            },
        )
        metadata.update(
            {
                "cover": f"assets/{cover['path'].name}",
                "cover_prompt": cover["prompt"],
                "cover_model": cover["model"],
                "cover_width": cover["width"],
                "cover_height": cover["height"],
                "cover_fallback": cover["is_fallback"],
            }
        )
        story_path.write_text(render_document(metadata, body), encoding="utf-8")


def resolve_agent_identity(agent_result: Path, protocol_log: Path) -> tuple[str, str]:
    result = json.loads(agent_result.read_text(encoding="utf-8")) if agent_result.is_file() else {}
    model = result.get("model")
    provider = result.get("model_provider")
    if not isinstance(model, str) or not isinstance(provider, str):
        with protocol_log.open(encoding="utf-8") as lines:
            for line in lines:
                row = json.loads(line)
                payload = row.get("payload")
                if not isinstance(payload, dict):
                    continue
                response = payload.get("result")
                if not isinstance(response, dict):
                    continue
                candidate_model = response.get("model")
                candidate_provider = response.get("modelProvider")
                if isinstance(candidate_model, str) and isinstance(candidate_provider, str):
                    model = candidate_model
                    provider = candidate_provider
                    break
    if not isinstance(model, str) or not model or not isinstance(provider, str) or not provider:
        raise ValueError("Nightjar model identity is unavailable")
    return model, provider


def stamp_agent_provenance(
    workspace: Path,
    run_date: str,
    agent_result: Path,
    protocol_log: Path,
) -> dict:
    model, provider = resolve_agent_identity(agent_result, protocol_log)
    edition_path = workspace / "content" / "editions" / run_date / "edition.md"
    edition, _ = parse_document(edition_path)
    filenames = edition.get("stories")
    if not isinstance(filenames, list):
        raise ValueError("target edition stories must be a list")
    for filename in filenames:
        if not isinstance(filename, str) or Path(filename).name != filename:
            raise ValueError("target edition contains an unsafe story path")
        story_path = edition_path.parent / filename
        metadata, body = parse_document(story_path)
        metadata["model_provider"] = provider
        metadata["model_name"] = model
        story_path.write_text(render_document(metadata, body), encoding="utf-8")
    return {"model": model, "model_provider": provider, "stories": len(filenames)}


def validate_workspace(root: Path, workspace: Path, run_date: str) -> dict:
    unexpected = {path.name for path in workspace.iterdir()} - WORKSPACE_FILES
    if unexpected:
        raise ValueError("unexpected workspace output: " + ", ".join(sorted(unexpected)))
    content = workspace / "content"
    protect_existing_content(root / "content", content, run_date)
    parse_preferences(content / "preferences.md")
    target = content / "editions" / run_date / "edition.md"
    if not target.is_file():
        raise ValueError(f"Nightjar did not prepare edition {run_date}")
    ensure_target_covers(content, run_date)
    editions = []
    for path in sorted((content / "editions").glob("*/edition.md")):
        payload, _ = load_edition(path)
        editions.append(payload)
    payload = next((value for value in editions if value["date"] == run_date), None)
    if payload is None or payload["id"] != f"edition-{run_date}":
        raise ValueError("target edition identity does not match its run date")
    if not 8 <= len(payload["items"]) <= 12:
        raise ValueError("target edition must contain 8 to 12 stories")
    if sum(item["kind"] == "event" for item in payload["items"]) > 2:
        raise ValueError("target edition must contain at most two event stories")
    for item in payload["items"]:
        urls = [item["source_url"], *(citation["url"] for citation in item["citations"])]
        if any(not value.startswith("https://") for value in urls):
            raise ValueError(f"story {item['id']} contains a non-HTTPS source")
    for path in sorted((content / "deep-dives" / "ready").glob("*.md")):
        load_deep_dive(path)
    berlin_now = datetime.fromisoformat(run_date).replace(hour=8, tzinfo=ZoneInfo("Europe/Berlin"))
    explore, _ = build_explore(content, now=berlin_now)
    write_explore(content, explore)
    return {
        "date": run_date,
        "stories": len(payload["items"]),
        "citations": sum(len(item["citations"]) for item in payload["items"]),
        "featured_events": len(explore["featured_events"]),
        "calendar_occurrences": len(explore["calendar"]),
    }


def publish_workspace(root: Path, workspace: Path, backup: Path) -> None:
    destination = root / "content"
    candidate = workspace / "content"
    staging = root / f".content-nightjar-{uuid.uuid4().hex}.tmp"
    if backup.exists():
        raise FileExistsError(backup)
    shutil.copytree(candidate, staging)
    destination.replace(backup)
    try:
        staging.replace(destination)
    except Exception:
        backup.replace(destination)
        raise


def rollback_workspace(root: Path, backup: Path) -> None:
    destination = root / "content"
    failed = root / f".content-nightjar-{uuid.uuid4().hex}.failed"
    if not backup.is_dir():
        raise FileNotFoundError(backup)
    if destination.exists():
        destination.replace(failed)
    backup.replace(destination)
    shutil.rmtree(failed, ignore_errors=True)


def backup_database(database: Path, backup: Path) -> None:
    if backup.exists():
        raise FileExistsError(backup)
    backup.parent.mkdir(parents=True, exist_ok=True)
    source = sqlite3.connect(f"file:{database}?mode=ro", uri=True)
    destination = sqlite3.connect(backup)
    source.backup(destination)
    destination.close()
    source.close()


def restore_database(database: Path, backup: Path) -> None:
    if not backup.is_file():
        raise FileNotFoundError(backup)
    source = sqlite3.connect(f"file:{backup}?mode=ro", uri=True)
    destination = sqlite3.connect(database)
    source.backup(destination)
    destination.close()
    source.close()


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser()
    commands = result.add_subparsers(dest="command", required=True)
    prepare = commands.add_parser("prepare")
    prepare.add_argument("--root", type=Path, required=True)
    prepare.add_argument("--workspace", type=Path, required=True)
    prepare.add_argument("--database", type=Path)
    validate = commands.add_parser("validate")
    validate.add_argument("--root", type=Path, required=True)
    validate.add_argument("--workspace", type=Path, required=True)
    validate.add_argument("--date", required=True)
    stamp = commands.add_parser("stamp-provenance")
    stamp.add_argument("--workspace", type=Path, required=True)
    stamp.add_argument("--date", required=True)
    stamp.add_argument("--agent-result", type=Path, required=True)
    stamp.add_argument("--protocol-log", type=Path, required=True)
    publish = commands.add_parser("publish")
    publish.add_argument("--root", type=Path, required=True)
    publish.add_argument("--workspace", type=Path, required=True)
    publish.add_argument("--backup", type=Path, required=True)
    rollback = commands.add_parser("rollback")
    rollback.add_argument("--root", type=Path, required=True)
    rollback.add_argument("--backup", type=Path, required=True)
    backup_database_command = commands.add_parser("backup-database")
    backup_database_command.add_argument("--database", type=Path, required=True)
    backup_database_command.add_argument("--backup", type=Path, required=True)
    restore_database_command = commands.add_parser("restore-database")
    restore_database_command.add_argument("--database", type=Path, required=True)
    restore_database_command.add_argument("--backup", type=Path, required=True)
    finalize = commands.add_parser("finalize")
    finalize.add_argument("--backup", type=Path, required=True)
    finalize.add_argument("--database-backup", type=Path)
    return result


def main() -> int:
    args = parser().parse_args()
    if args.command == "prepare":
        prepare_workspace(args.root, args.workspace, args.database)
    elif args.command == "validate":
        print(json.dumps(validate_workspace(args.root, args.workspace, args.date), sort_keys=True))
    elif args.command == "stamp-provenance":
        print(
            json.dumps(
                stamp_agent_provenance(
                    args.workspace,
                    args.date,
                    args.agent_result,
                    args.protocol_log,
                ),
                sort_keys=True,
            )
        )
    elif args.command == "publish":
        publish_workspace(args.root, args.workspace, args.backup)
    elif args.command == "rollback":
        rollback_workspace(args.root, args.backup)
    elif args.command == "backup-database":
        backup_database(args.database, args.backup)
    elif args.command == "restore-database":
        restore_database(args.database, args.backup)
    else:
        shutil.rmtree(args.backup, ignore_errors=True)
        if args.database_backup:
            args.database_backup.unlink(missing_ok=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
