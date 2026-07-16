#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
import selectors
import subprocess
import sys
import time
from pathlib import Path


AGENT_ENVIRONMENT_KEYS = {
    "CODEX_HOME",
    "HOME",
    "LANG",
    "LC_ALL",
    "LOGNAME",
    "PATH",
    "SHELL",
    "TERM",
    "TMPDIR",
    "USER",
    "XDG_CACHE_HOME",
    "XDG_CONFIG_HOME",
    "XDG_DATA_HOME",
}


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cwd", required=True)
    parser.add_argument("--name", required=True)
    parser.add_argument("--prompt-file", action="append", default=[])
    parser.add_argument("--prompt", action="append", default=[])
    parser.add_argument("--result-file", required=True)
    parser.add_argument("--protocol-log", required=True)
    parser.add_argument("--timeout-seconds", type=int, default=10800)
    parser.add_argument("--model")
    parser.add_argument("--effort", default="high")
    parser.add_argument("--approval-policy", default="never")
    parser.add_argument("--sandbox", choices=("read-only", "workspace-write", "danger-full-access"), default="workspace-write")
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def build_prompt(args):
    parts = []
    for prompt_file in args.prompt_file:
        parts.append(Path(prompt_file).read_text(encoding="utf-8"))
    parts.extend(args.prompt)
    return "\n\n".join(part.strip() for part in parts if part.strip()) + "\n"


def agent_environment():
    return {key: os.environ[key] for key in AGENT_ENVIRONMENT_KEYS if os.environ.get(key)}


def sandbox_policy(mode, cwd):
    if mode == "danger-full-access":
        return {"type": "dangerFullAccess"}
    if mode == "read-only":
        return {"type": "readOnly", "networkAccess": True}
    return {
        "type": "workspaceWrite",
        "writableRoots": [str(Path(cwd).resolve())],
        "networkAccess": True,
    }


def should_wait_for_retry(params):
    return bool(params.get("willRetry"))


class AppServer:
    def __init__(self, protocol_log, cwd):
        self.protocol_log = protocol_log
        self.next_id = 1
        self.selector = selectors.DefaultSelector()
        self.process = subprocess.Popen(
            ["codex", "app-server", "--listen", "stdio://"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,
            cwd=cwd,
            env=agent_environment(),
        )
        self.selector.register(self.process.stdout, selectors.EVENT_READ, "stdout")
        self.selector.register(self.process.stderr, selectors.EVENT_READ, "stderr")

    def close(self):
        if self.process.poll() is None:
            self.process.terminate()
            try:
                self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.process.kill()

    def log(self, direction, payload):
        self.protocol_log.write(json.dumps({"direction": direction, "payload": payload}, ensure_ascii=False) + "\n")
        self.protocol_log.flush()

    def send(self, method, params):
        request_id = self.next_id
        self.next_id += 1
        message = {"jsonrpc": "2.0", "id": request_id, "method": method, "params": params}
        self.log("send", message)
        self.process.stdin.write(json.dumps(message, ensure_ascii=False) + "\n")
        self.process.stdin.flush()
        return request_id

    def respond_error(self, request_id, message):
        response = {"jsonrpc": "2.0", "id": request_id, "error": {"code": -32603, "message": message}}
        self.log("send", response)
        self.process.stdin.write(json.dumps(response, ensure_ascii=False) + "\n")
        self.process.stdin.flush()

    def read(self, deadline):
        while time.time() < deadline:
            events = self.selector.select(timeout=min(1, max(0, deadline - time.time())))
            if not events:
                if self.process.poll() is not None:
                    raise RuntimeError(f"codex app-server exited {self.process.returncode}")
                continue
            for key, _ in events:
                line = key.fileobj.readline()
                if not line:
                    if self.process.poll() is not None:
                        raise RuntimeError(f"codex app-server exited {self.process.returncode}")
                    continue
                if key.data == "stderr":
                    self.log("stderr", line.rstrip("\n"))
                    continue
                payload = json.loads(line)
                self.log("recv", payload)
                return payload
        raise TimeoutError("timed out waiting for codex app-server")

    def request(self, method, params, deadline):
        request_id = self.send(method, params)
        while True:
            payload = self.read(deadline)
            if payload.get("id") == request_id:
                if "error" in payload:
                    raise RuntimeError(json.dumps(payload["error"], ensure_ascii=False))
                return payload["result"]
            if "id" in payload and "method" in payload:
                self.respond_error(payload["id"], "scheduled helper cannot service server requests")


def main():
    args = parse_args()
    prompt = build_prompt(args)
    result_path = Path(args.result_file)
    protocol_path = Path(args.protocol_log)
    result_path.parent.mkdir(parents=True, exist_ok=True)
    protocol_path.parent.mkdir(parents=True, exist_ok=True)
    started_at = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    prompt_hash = hashlib.sha256(prompt.encode()).hexdigest()

    if args.dry_run:
        print(prompt)
        return 0

    result = {
        "name": args.name,
        "cwd": args.cwd,
        "started_at": started_at,
        "prompt_sha256": prompt_hash,
        "status": "started",
    }

    with protocol_path.open("a", encoding="utf-8") as protocol_log:
        server = AppServer(protocol_log, args.cwd)
        deadline = time.time() + args.timeout_seconds
        final_text = []
        try:
            server.request(
                "initialize",
                {
                    "clientInfo": {
                        "name": "verse-nightjar",
                        "title": "Verse Nightjar",
                        "version": "0.1.0",
                    },
                    "capabilities": {"experimentalApi": True},
                },
                deadline,
            )
            thread_response = server.request(
                "thread/start",
                {
                    "cwd": args.cwd,
                    "approvalPolicy": args.approval_policy,
                    "sandbox": args.sandbox,
                    "runtimeWorkspaceRoots": [str(Path(args.cwd).resolve())],
                    "ephemeral": False,
                    "sessionStartSource": "startup",
                    "threadSource": "user",
                    **({"model": args.model} if args.model else {}),
                },
                deadline,
            )
            thread_id = thread_response["thread"]["id"]
            result["thread_id"] = thread_id
            result["model"] = thread_response.get("model")
            result["model_provider"] = thread_response.get("modelProvider")
            server.request("thread/name/set", {"threadId": thread_id, "name": args.name}, deadline)
            turn_response = server.request(
                "turn/start",
                {
                    "threadId": thread_id,
                    "input": [{"type": "text", "text": prompt, "text_elements": []}],
                    "approvalPolicy": args.approval_policy,
                    "sandboxPolicy": sandbox_policy(args.sandbox, args.cwd),
                    "runtimeWorkspaceRoots": [str(Path(args.cwd).resolve())],
                    "effort": args.effort,
                },
                deadline,
            )
            result["turn_start_response"] = turn_response
            result["status"] = "running"
            result_path.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
            while True:
                payload = server.read(deadline)
                if "id" in payload and "method" in payload:
                    server.respond_error(payload["id"], "scheduled helper cannot service server requests")
                    continue
                method = payload.get("method")
                params = payload.get("params") or {}
                if method == "item/agentMessage/delta" and params.get("threadId") == thread_id:
                    final_text.append(params.get("delta", ""))
                if method == "error" and params.get("threadId") == thread_id:
                    if should_wait_for_retry(params):
                        continue
                    result["status"] = "failed"
                    result["error"] = params
                    break
                if method == "turn/completed" and params.get("threadId") == thread_id:
                    turn = params.get("turn") or {}
                    result["status"] = turn.get("status", "completed")
                    result["turn"] = turn
                    break
        except Exception as exc:
            result["status"] = "failed"
            result["error"] = str(exc)
        finally:
            result["completed_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
            result["assistant_text"] = "".join(final_text).strip()
            result_path.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
            server.close()

    return 0 if result.get("status") == "completed" else 1


if __name__ == "__main__":
    sys.exit(main())
