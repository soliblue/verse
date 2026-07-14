import hashlib
import json
import os
import re
import shlex
import subprocess
import tempfile
from pathlib import Path

from db.connection import utc_now


ROOT = Path(__file__).resolve().parents[1]
AGENT_ENVIRONMENT_KEYS = {
    "CODEX_HOME",
    "HOME",
    "LANG",
    "LC_ALL",
    "PATH",
    "SSL_CERT_DIR",
    "SSL_CERT_FILE",
    "TERM",
}


def agent_environment() -> dict[str, str]:
    return {key: os.environ[key] for key in AGENT_ENVIRONMENT_KEYS if os.environ.get(key)}


def resolved_model(stderr: str, requested: str | None) -> str:
    match = re.search(r"^\s*model:\s*(\S+)\s*$", stderr, re.MULTILINE)
    return match.group(1) if match else requested or "unknown"


def prompt_text(name: str) -> str:
    return (ROOT / "prompts" / name).read_text(encoding="utf-8").strip()


def write_protocol_log(run_id: str, payload: dict) -> Path:
    directory = Path(os.environ.get("VERSE_RUNS_DIR", "runs")) / re.sub(r"[^a-zA-Z0-9._-]", "-", run_id)
    directory.mkdir(parents=True, exist_ok=True)
    destination = directory / "agent-protocol.json"
    temporary = destination.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(destination)
    return destination


def run_agent_json(prompt: str, timeout_seconds: int = 3600, run_id: str = "manual") -> tuple[dict, dict]:
    prompt_hash = hashlib.sha256(prompt.encode()).hexdigest()
    with tempfile.TemporaryDirectory(prefix="verse-agent-") as directory:
        output = Path(directory) / "response.json"
        configured = os.environ.get("VERSE_AGENT_COMMAND")
        model = os.environ.get("VERSE_AGENT_MODEL") or None
        command = (
            [part.format(output=str(output)) for part in shlex.split(configured)]
            if configured
            else [
                "codex",
                "exec",
                "--ephemeral",
                "--ignore-user-config",
                "--ignore-rules",
                "--skip-git-repo-check",
                "--sandbox",
                "read-only",
                "--disable",
                "apps",
                "--disable",
                "browser_use",
                "--disable",
                "browser_use_external",
                "--disable",
                "browser_use_full_cdp_access",
                "--disable",
                "code_mode_host",
                "--disable",
                "computer_use",
                "--disable",
                "image_generation",
                "--disable",
                "in_app_browser",
                "--disable",
                "multi_agent",
                "--disable",
                "plugins",
                "--disable",
                "shell_tool",
                "--disable",
                "tool_suggest",
                "--disable",
                "unified_exec",
                *(["--model", model] if model else []),
                "--output-last-message",
                str(output),
                "-",
            ]
        )
        result = subprocess.run(
            command,
            cwd=directory,
            env={**agent_environment(), "TMPDIR": directory},
            input=prompt,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout_seconds,
            check=False,
        )
        output_text = output.read_text(encoding="utf-8") if output.exists() else ""
        protocol_path = write_protocol_log(
            run_id,
            {
                "provider": command[0],
                "started_from": "verse-nightjar",
                "prompt_sha256": prompt_hash,
                "return_code": result.returncode,
                "completed_at": utc_now(),
                "stdout": result.stdout,
                "stderr": result.stderr,
                "response": output_text,
            },
        )
        if result.returncode != 0:
            raise RuntimeError(f"agent command exited {result.returncode}: {result.stderr[-2000:]}")
        response = json.loads(output_text)
    provenance = {
        "provider": command[0],
        "command": configured or "isolated codex exec --sandbox read-only --output-last-message {output} -",
        "model": resolved_model(result.stderr, model),
        "prompt_versions": ["editor-v1", "summary-v1", "deep-dive-v1"],
        "prompt_sha256": prompt_hash,
        "protocol_log": str(protocol_path),
        "completed_at": utc_now(),
    }
    return response, provenance
