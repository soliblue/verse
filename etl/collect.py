import hashlib
import json
import re
import sqlite3
from datetime import datetime
from pathlib import Path
from urllib.parse import urlparse
from urllib.request import Request, urlopen

from db.connection import json_text, utc_now
from etl.feeds import parse_json_feed, parse_json_ld_html, parse_xml_feed


MAXIMUM_SOURCE_BYTES = 5_000_000


def term_present(text: str, term: str) -> bool:
    return re.search(rf"(?<!\w){re.escape(term)}(?!\w)", text) is not None


def fetch(source: dict, timeout_seconds: int) -> list[dict]:
    request = Request(source["url"], headers={"Accept": "application/feed+json, application/atom+xml, application/rss+xml, application/xml", "User-Agent": "Morrow-Nightjar/0"})
    with urlopen(request, timeout=timeout_seconds) as response:
        data = response.read(MAXIMUM_SOURCE_BYTES + 1)
        content_type = response.headers.get_content_type()
    if len(data) > MAXIMUM_SOURCE_BYTES:
        raise ValueError("source response exceeds 5 MB")
    items = (
        parse_json_feed(data)
        if source.get("format") == "json" or content_type == "application/feed+json"
        else parse_json_ld_html(data)
        if source.get("format") == "html_jsonld"
        else parse_xml_feed(data)
    )
    return items[: int(source.get("max_items", 30))]


def load_sources(path: Path) -> list[dict]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict) or not isinstance(payload.get("sources"), list):
        raise ValueError("sources file must contain a sources array")
    identifiers = []
    for index, source in enumerate(payload["sources"]):
        if not isinstance(source, dict):
            raise ValueError(f"sources[{index}] must be an object")
        for field in ("id", "name", "url"):
            if not isinstance(source.get(field), str) or not source[field].strip():
                raise ValueError(f"sources[{index}].{field} must be a non-empty string")
        if urlparse(source["url"]).scheme not in {"http", "https"}:
            raise ValueError(f"sources[{index}].url must be http or https")
        if not isinstance(source.get("topic_ids"), list) or not source["topic_ids"]:
            raise ValueError(f"sources[{index}].topic_ids must be a non-empty array")
        identifiers.append(source["id"])
    if len(identifiers) != len(set(identifiers)):
        raise ValueError("source ids must be unique")
    return payload["sources"]


def collect_stage(
    connection: sqlite3.Connection,
    run_id: str,
    sources_path: Path,
    timeout_seconds: int = 20,
) -> int:
    edition_date = connection.execute("SELECT edition_date FROM etl_runs WHERE id = ?", (run_id,)).fetchone()[0]
    run_date = datetime.fromisoformat(edition_date)
    total = 0
    failures = []
    with connection:
        connection.execute("DELETE FROM run_source_items WHERE run_id = ?", (run_id,))
        connection.execute("DELETE FROM etl_source_results WHERE run_id = ?", (run_id,))
    for source in load_sources(sources_path):
        source = {
            **source,
            "url": source["url"].format(
                date=edition_date,
                year=run_date.year,
                month=run_date.strftime("%B").lower(),
            ),
        }
        started_at = utc_now()
        try:
            items = fetch(source, timeout_seconds)
            include_terms = [term.lower() for term in source.get("include_terms", [])]
            exclude_terms = [term.lower() for term in source.get("exclude_terms", [])]
            valid_items = []
            for item in items:
                searchable = f"{item.get('title', '')} {item.get('content', '')}".lower()
                complete = all(item.get(field) for field in ("external_id", "title", "url", "published_at", "content"))
                parsed_url = urlparse(item["url"]) if isinstance(item.get("url"), str) else None
                valid_url = parsed_url is not None and parsed_url.scheme in {"http", "https"} and bool(parsed_url.netloc)
                included = not include_terms or any(term_present(searchable, term) for term in include_terms)
                excluded = any(term_present(searchable, term) for term in exclude_terms)
                if complete and valid_url and included and not excluded:
                    valid_items.append(item)
            now = utc_now()
            with connection:
                for item in valid_items:
                    identifier = hashlib.sha256(f"{source['id']}\0{item['external_id']}".encode()).hexdigest()
                    citations = [{"title": item["title"], "url": item["url"], "source_name": source["name"], "published_at": item["published_at"]}]
                    raw = {"item": item, "source": source}
                    content_hash = hashlib.sha256(json_text(raw).encode()).hexdigest()
                    connection.execute(
                        "INSERT INTO source_items (id, source_id, external_id, source_name, title, url, author, published_at, content, citations_json, topic_ids_json, raw_json, content_hash, collected_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(source_id, external_id) DO UPDATE SET source_name = excluded.source_name, title = excluded.title, url = excluded.url, author = excluded.author, published_at = excluded.published_at, content = excluded.content, citations_json = excluded.citations_json, topic_ids_json = excluded.topic_ids_json, raw_json = excluded.raw_json, content_hash = excluded.content_hash, updated_at = excluded.updated_at",
                        (
                            identifier,
                            source["id"],
                            str(item["external_id"]),
                            source["name"],
                            item["title"],
                            item["url"],
                            item.get("author"),
                            item["published_at"],
                            item["content"],
                            json_text(citations),
                            json_text(source.get("topic_ids", [])),
                            json_text(raw),
                            content_hash,
                            now,
                            now,
                        ),
                    )
                    connection.execute(
                        "INSERT OR IGNORE INTO run_source_items (run_id, source_item_id) VALUES (?, ?)", (run_id, identifier)
                    )
                connection.execute(
                    "INSERT INTO etl_source_results (run_id, source_id, status, item_count, error, started_at, completed_at) VALUES (?, ?, 'completed', ?, NULL, ?, ?)",
                    (run_id, source["id"], len(valid_items), started_at, utc_now()),
                )
            total += len(valid_items)
        except Exception as error:
            failures.append(f"{source.get('id', 'unknown')}: {error}")
            with connection:
                connection.execute(
                    "INSERT INTO etl_source_results (run_id, source_id, status, item_count, error, started_at, completed_at) VALUES (?, ?, 'failed', 0, ?, ?, ?)",
                    (run_id, source.get("id", "unknown"), str(error)[:4000], started_at, utc_now()),
                )
    if total == 0:
        raise RuntimeError("no source items collected" + (f": {'; '.join(failures)}" if failures else ""))
    return total
