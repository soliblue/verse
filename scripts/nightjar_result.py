import argparse
import json
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--path", type=Path, required=True)
    parser.add_argument("--status", required=True)
    parser.add_argument("--date", required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--started-at", required=True)
    parser.add_argument("--completed-at")
    parser.add_argument("--exit-code", type=int)
    parser.add_argument("--preflight-log", required=True)
    parser.add_argument("--pipeline-log", required=True)
    args = parser.parse_args()
    payload = {
        "status": args.status,
        "date": args.date,
        "run_id": args.run_id,
        "started_at": args.started_at,
        "completed_at": args.completed_at,
        "exit_code": args.exit_code,
        "preflight_log": args.preflight_log,
        "pipeline_log": args.pipeline_log,
    }
    args.path.parent.mkdir(parents=True, exist_ok=True)
    temporary = args.path.with_suffix(args.path.suffix + ".tmp")
    temporary.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(args.path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
