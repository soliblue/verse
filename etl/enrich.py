import hashlib
import json
import math
import re
import sqlite3
import subprocess

from db.connection import json_text, utc_now
from db.repository import fail_deep_dive
from etl.agent import prompt_text, run_agent_json
from etl.validation import require_text, validate_citations


def sentences(value: str) -> list[str]:
    return [part.strip() for part in re.split(r"(?<=[.!?])\s+", value) if part.strip()]


def deterministic_story(row: sqlite3.Row) -> dict:
    content_sentences = sentences(row["content"])
    summary = " ".join(content_sentences[:2])[:480].strip()
    if not summary:
        summary = row["title"]
    topic_ids = json.loads(row["topic_ids_json"])
    lowered = f"{row['title']} {row['source_name']} {' '.join(topic_ids)}".lower()
    kind = "event" if any(term in lowered for term in ("event", "berlin", "festival", "exhibition", "performance")) else (
        "paper" if any(term in lowered for term in ("arxiv", "paper", "research", "lab")) else "technique"
    )
    topic_label = ", ".join(topic_ids[:2]).replace("-", " ") or "your interests"
    return {
        "title": row["title"],
        "summary": summary,
        "body": row["content"][:6000].strip(),
        "why_selected": f"Selected for its connection to {topic_label}, source quality, and novelty.",
        "kind": kind,
    }


def agent_prompt(rows: list[sqlite3.Row], deep_dives: list[dict]) -> str:
    candidates = [
        {
            "normalized_item_id": row["normalized_item_id"],
            "title": row["title"],
            "source_name": row["source_name"],
            "source_url": row["canonical_url"],
            "published_at": row["published_at"],
            "content": row["content"][:6000],
            "topic_ids": json.loads(row["topic_ids_json"]),
            "citations": json.loads(row["citations_json"]),
            "ranking_rationale": row["rationale"],
        }
        for row in rows
    ]
    payload = {"candidates": candidates, "deep_dive_requests": deep_dives}
    return f"{prompt_text('editor-v1.md')}\n\n{prompt_text('summary-v1.md')}\n\n{prompt_text('deep-dive-v1.md')}\n\nInput JSON:\n{json.dumps(payload, ensure_ascii=False)}\n"


def queued_deep_dives(connection: sqlite3.Connection, limit: int = 3) -> list[dict]:
    rows = connection.execute(
        "SELECT d.story_id, e.payload_json, i.evidence_json FROM deep_dives d "
        "JOIN edition_items i ON i.story_id = d.story_id "
        "JOIN editions e ON e.id = i.edition_id "
        "WHERE d.status = 'queued' ORDER BY e.edition_date DESC, e.generated_at DESC"
    ).fetchall()
    requests = []
    seen = set()
    for row in rows:
        if row["story_id"] in seen:
            continue
        seen.add(row["story_id"])
        item = next(item for item in json.loads(row["payload_json"])["items"] if item["id"] == row["story_id"])
        evidence = json.loads(row["evidence_json"])
        source = evidence.get("source") if isinstance(evidence, dict) else None
        source = source if isinstance(source, dict) else {}
        source.setdefault("title", item["title"])
        source.setdefault("url", item["source_url"])
        source.setdefault("source_name", item["source_name"])
        source.setdefault("published_at", item["published_at"])
        content = source.get("content") if isinstance(source.get("content"), str) else item["body"]
        source["content"] = (content or item["body"])[:12000]
        evidence = {**evidence, "source": source} if isinstance(evidence, dict) else {"source": source}
        evidence.setdefault("citations", item["citations"])
        requests.append(
            {
                "story_id": item["id"],
                "title": item["title"],
                "summary": item["summary"],
                "citations": item["citations"],
                "evidence": evidence,
            }
        )
        if len(requests) == limit:
            break
    return requests


def enrich_deep_dives(
    connection: sqlite3.Connection,
    run_id: str,
    requests: list[dict],
    timeout_seconds: int,
) -> None:
    for request in requests:
        try:
            response, provenance = run_agent_json(
                agent_prompt([], [request]),
                timeout_seconds,
                f"{run_id}-deep-{request['story_id']}",
            )
            validate_agent_items(response, [])
            payload = validate_agent_deep_dives(response, [request])[request["story_id"]]
        except (RuntimeError, subprocess.TimeoutExpired, ValueError) as error:
            fail_deep_dive(connection, request["story_id"], error)
            continue
        with connection:
            connection.execute(
                "INSERT INTO run_deep_dives "
                "(run_id, story_id, payload_json, model_provenance_json) VALUES (?, ?, ?, ?) "
                "ON CONFLICT(run_id, story_id) DO UPDATE SET payload_json = excluded.payload_json, "
                "model_provenance_json = excluded.model_provenance_json",
                (run_id, request["story_id"], json_text(payload), json_text(provenance)),
            )


def validate_agent_items(response: dict, rows: list[sqlite3.Row]) -> dict[str, dict]:
    values = response.get("items")
    if not isinstance(values, list):
        raise ValueError("agent response must contain an items array")
    by_id = {}
    for index, item in enumerate(values):
        if not isinstance(item, dict):
            raise ValueError(f"agent items[{index}] must be an object")
        identifier = require_text(item.get("normalized_item_id"), f"agent items[{index}].normalized_item_id")
        for field in ("title", "summary", "body", "why_selected"):
            require_text(item.get(field), f"agent items[{index}].{field}")
        if item.get("kind") not in {"paper", "event", "technique"}:
            raise ValueError(f"agent items[{index}].kind is invalid")
        by_id[identifier] = item
    expected = {row["normalized_item_id"] for row in rows}
    if set(by_id) != expected or len(values) != len(expected):
        raise ValueError("agent response item ids do not match selected candidates")
    return by_id


def validate_agent_deep_dives(response: dict, requests: list[dict]) -> dict[str, dict]:
    values = response.get("deep_dives", [])
    if not isinstance(values, list):
        raise ValueError("agent response deep_dives must be an array")
    by_id = {}
    allowed = {
        request["story_id"]: {json.dumps(citation, sort_keys=True, separators=(",", ":")) for citation in request["citations"]}
        for request in requests
    }
    for index, item in enumerate(values):
        if not isinstance(item, dict):
            raise ValueError(f"agent deep_dives[{index}] must be an object")
        identifier = require_text(item.get("story_id"), f"agent deep_dives[{index}].story_id")
        require_text(item.get("title"), f"agent deep_dives[{index}].title")
        require_text(item.get("body"), f"agent deep_dives[{index}].body")
        validate_citations(item.get("citations"), f"agent deep_divives[{index}].citations")
        if identifier not in allowed or any(
            json.dumps(citation, sort_keys=True, separators=(",", ":")) not in allowed[identifier] for citation in item["citations"]
        ):
            raise ValueError("deep-dive citations must come from stored source evidence")
        by_id[identifier] = item
    if set(by_id) != set(allowed) or len(values) != len(allowed):
        raise ValueError("agent response deep-dive ids do not match queued requests")
    return by_id


def enrich_stage(
    connection: sqlite3.Connection,
    run_id: str,
    use_agent: bool = False,
    timeout_seconds: int = 3600,
) -> int:
    rows = connection.execute(
        "SELECT c.normalized_item_id, c.rationale, n.* FROM run_candidates c JOIN normalized_items n ON n.id = c.normalized_item_id WHERE c.run_id = ? AND c.selected = 1 ORDER BY c.total_score DESC, n.id",
        (run_id,),
    ).fetchall()
    if not 8 <= len(rows) <= 12:
        raise ValueError("enrichment requires between 8 and 12 selected candidates")
    deep_dive_requests = queued_deep_dives(connection)
    generated = {row["normalized_item_id"]: deterministic_story(row) for row in rows}
    provenance = {"provider": "deterministic", "prompt_version": "summary-v1", "completed_at": utc_now()}
    if use_agent:
        response, provenance = run_agent_json(agent_prompt(rows, []), timeout_seconds, run_id)
        generated = validate_agent_items(response, rows)
        validate_agent_deep_dives(response, [])
    with connection:
        connection.execute("DELETE FROM draft_stories WHERE run_id = ?", (run_id,))
        connection.execute("DELETE FROM run_deep_dives WHERE run_id = ?", (run_id,))
        for position, row in enumerate(rows, start=1):
            fields = generated[row["normalized_item_id"]]
            story_id = "story-" + hashlib.sha256(row["canonical_url"].encode()).hexdigest()[:20]
            content = {
                "id": story_id,
                "position": position,
                "kind": fields["kind"],
                "topic_ids": json.loads(row["topic_ids_json"]),
                "title": fields["title"],
                "summary": fields["summary"],
                "body": fields["body"],
                "why_selected": fields["why_selected"],
                "source_name": row["source_name"],
                "source_url": row["canonical_url"],
                "published_at": row["published_at"],
                "reading_minutes": max(1, math.ceil(len(fields["body"].split()) / 220)),
                "image_url": None,
                "citations": json.loads(row["citations_json"]),
            }
            connection.execute(
                "INSERT INTO draft_stories (run_id, story_id, normalized_item_id, position, payload_json, evidence_json, model_provenance_json) VALUES (?, ?, ?, ?, ?, ?, ?)",
                (
                    run_id,
                    story_id,
                    row["normalized_item_id"],
                    position,
                    json_text(content),
                    row["evidence_json"],
                    json_text(provenance),
                ),
            )
    if use_agent:
        enrich_deep_dives(connection, run_id, deep_dive_requests, timeout_seconds)
    return len(rows)
