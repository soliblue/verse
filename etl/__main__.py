import argparse
import json
import os
from datetime import UTC, datetime
from pathlib import Path

from db.connection import connect
from db.content import sync_content
from db.environment import load_environment
from db.explore import event_ranking_profile, publish_explore
from db.migrations import migrate
from etl.collect import collect_stage
from etl.content import content_root
from etl.deduplicate import deduplicate_stage
from etl.enrich import enrich_stage
from etl.explore import build_explore, write_explore
from etl.normalize import normalize_stage
from etl.rank import rank_stage
from etl.runs import STAGES, require_run, run_stage, start_run
from etl.write import write_stage


def add_shared_stage_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--force", action="store_true")


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(prog="python -m etl")
    commands = result.add_subparsers(dest="command", required=True)
    start = commands.add_parser("start")
    start.add_argument("--date", required=True)
    start.add_argument("--run-id")
    status = commands.add_parser("status")
    status.add_argument("--run-id", required=True)
    collect = commands.add_parser("collect")
    add_shared_stage_arguments(collect)
    collect.add_argument("--sources", type=Path, default=Path(os.environ.get("VERSE_SOURCES_FILE", "etl/sources.json")))
    collect.add_argument("--timeout-seconds", type=int, default=20)
    normalize = commands.add_parser("normalize")
    add_shared_stage_arguments(normalize)
    deduplicate = commands.add_parser("deduplicate")
    add_shared_stage_arguments(deduplicate)
    rank = commands.add_parser("rank")
    add_shared_stage_arguments(rank)
    rank.add_argument("--selection-limit", type=int, default=10)
    enrich = commands.add_parser("enrich")
    add_shared_stage_arguments(enrich)
    enrich.add_argument("--agent", action="store_true")
    enrich.add_argument("--agent-timeout-seconds", type=int, default=3600)
    write = commands.add_parser("write")
    add_shared_stage_arguments(write)
    commands.add_parser("materialize")
    nightly = commands.add_parser("nightly")
    nightly.add_argument("--date", default=datetime.now(UTC).date().isoformat())
    nightly.add_argument("--run-id")
    nightly.add_argument("--sources", type=Path, default=Path(os.environ.get("VERSE_SOURCES_FILE", "etl/sources.json")))
    nightly.add_argument("--source-timeout-seconds", type=int, default=20)
    nightly.add_argument("--selection-limit", type=int, default=10)
    nightly.add_argument("--agent", action="store_true")
    nightly.add_argument("--agent-timeout-seconds", type=int, default=3600)
    nightly.add_argument("--force", action="store_true")
    return result


def stage_action(args: argparse.Namespace, connection, stage: str):
    if stage == "collect":
        return lambda: collect_stage(connection, args.run_id, args.sources, args.timeout_seconds)
    if stage == "normalize":
        return lambda: normalize_stage(connection, args.run_id)
    if stage == "deduplicate":
        return lambda: deduplicate_stage(connection, args.run_id)
    if stage == "rank":
        return lambda: rank_stage(connection, args.run_id, args.selection_limit)
    if stage == "enrich":
        return lambda: enrich_stage(connection, args.run_id, args.agent, args.agent_timeout_seconds)
    return lambda: write_stage(connection, args.run_id)


def main() -> int:
    os.umask(0o077)
    load_environment()
    args = parser().parse_args()
    connection = connect()
    migrate(connection)
    root = content_root()
    materialized = None
    if root.is_dir():
        content_status = sync_content(connection, root, os.environ.get("VERSE_PUBLIC_BASE_URL") or None)
        materialized = {"content": content_status, "explore": None}
        if (root / "places.md").is_file():
            explore, source_events = build_explore(root, ranking_profile=event_ranking_profile(connection))
            write_explore(root, explore)
            publish_explore(connection, explore, source_events)
            materialized["explore"] = {
                "id": explore["id"],
                "featured_events": len(explore["featured_events"]),
                "calendar_occurrences": len(explore["calendar"]),
            }
    if args.command == "materialize":
        if materialized is None:
            raise RuntimeError(f"content directory does not exist: {root}")
        print(json.dumps(materialized, ensure_ascii=False, sort_keys=True))
        connection.close()
        return 0
    if args.command == "start":
        print(start_run(connection, args.date, args.run_id))
        connection.close()
        return 0
    if args.command == "status":
        run = dict(require_run(connection, args.run_id))
        run["stages"] = [
            dict(row)
            for row in connection.execute(
                "SELECT stage, status, row_count, started_at, completed_at, error FROM etl_stage_results WHERE run_id = ? ORDER BY started_at",
                (args.run_id,),
            )
        ]
        print(json.dumps(run, ensure_ascii=False, indent=2))
        connection.close()
        return 0
    if args.command in STAGES:
        count = run_stage(connection, args.run_id, args.command, stage_action(args, connection, args.command), args.force)
        print(f"run_id={args.run_id} stage={args.command} rows={count}")
        connection.close()
        return 0
    args.run_id = start_run(connection, args.date, args.run_id)
    actions = {
        "collect": lambda: collect_stage(connection, args.run_id, args.sources, args.source_timeout_seconds),
        "normalize": lambda: normalize_stage(connection, args.run_id),
        "deduplicate": lambda: deduplicate_stage(connection, args.run_id),
        "rank": lambda: rank_stage(connection, args.run_id, args.selection_limit),
        "enrich": lambda: enrich_stage(connection, args.run_id, args.agent, args.agent_timeout_seconds),
        "write": lambda: write_stage(connection, args.run_id),
    }
    for stage in STAGES:
        count = run_stage(connection, args.run_id, stage, actions[stage], args.force)
        print(f"run_id={args.run_id} stage={stage} rows={count}", flush=True)
    connection.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
