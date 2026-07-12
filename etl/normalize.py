import hashlib
import html
import json
import re
import sqlite3
from html.parser import HTMLParser
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

from db.connection import json_text, utc_now
from etl.validation import require_url, validate_citations


TRACKING_PARAMETERS = {"fbclid", "gclid", "mc_cid", "mc_eid", "ref", "ref_src"}


class TextExtractor(HTMLParser):
    def __init__(self):
        super().__init__()
        self.parts: list[str] = []

    def handle_data(self, data: str) -> None:
        self.parts.append(data)


def plain_text(value: str) -> str:
    parser = TextExtractor()
    parser.feed(value)
    return re.sub(r"\s+", " ", html.unescape(" ".join(parser.parts))).strip()


def canonical_url(value: str) -> str:
    require_url(value, "source_url")
    parsed = urlsplit(value)
    query = urlencode(
        sorted(
            (key, item)
            for key, item in parse_qsl(parsed.query, keep_blank_values=True)
            if not key.lower().startswith("utm_") and key.lower() not in TRACKING_PARAMETERS
        )
    )
    scheme = parsed.scheme.lower()
    host = parsed.netloc.lower()
    path = parsed.path.rstrip("/") or "/"
    if host in {"arxiv.org", "www.arxiv.org"}:
        scheme = "https"
        host = "arxiv.org"
        if path.startswith("/abs/"):
            path = re.sub(r"v\d+$", "", path)
    return urlunsplit((scheme, host, path, query, ""))


def normalize_stage(connection: sqlite3.Connection, run_id: str) -> int:
    rows = connection.execute(
        "SELECT s.* FROM source_items s JOIN run_source_items r ON r.source_item_id = s.id WHERE r.run_id = ? ORDER BY s.id",
        (run_id,),
    ).fetchall()
    now = utc_now()
    with connection:
        connection.execute("DELETE FROM run_normalized_items WHERE run_id = ?", (run_id,))
        for row in rows:
            url = canonical_url(row["url"])
            citations = [
                {**citation, "url": canonical_url(citation["url"])}
                for citation in json.loads(row["citations_json"])
            ]
            validate_citations(citations, f"source_items.{row['id']}.citations")
            content = plain_text(row["content"])
            title = plain_text(row["title"])
            if not title or not content:
                raise ValueError(f"source item {row['id']} has empty normalized text")
            identifier = hashlib.sha256(row["id"].encode()).hexdigest()
            content_hash = hashlib.sha256(f"{title}\0{content}\0{url}".encode()).hexdigest()
            evidence = {
                "source_item_id": row["id"],
                "source_content_hash": row["content_hash"],
                "citations": citations,
                "source": {
                    "title": title,
                    "url": url,
                    "author": row["author"],
                    "source_name": row["source_name"],
                    "published_at": row["published_at"],
                    "content": content,
                },
            }
            connection.execute(
                "INSERT INTO normalized_items (id, source_item_id, canonical_url, title, author, source_name, published_at, content, citations_json, topic_ids_json, evidence_json, content_hash, normalized_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET canonical_url = excluded.canonical_url, title = excluded.title, author = excluded.author, source_name = excluded.source_name, published_at = excluded.published_at, content = excluded.content, citations_json = excluded.citations_json, topic_ids_json = excluded.topic_ids_json, evidence_json = excluded.evidence_json, content_hash = excluded.content_hash, normalized_at = excluded.normalized_at",
                (
                    identifier,
                    row["id"],
                    url,
                    title,
                    row["author"],
                    row["source_name"],
                    row["published_at"],
                    content,
                    json_text(citations),
                    row["topic_ids_json"],
                    json_text(evidence),
                    content_hash,
                    now,
                ),
            )
            connection.execute(
                "INSERT OR IGNORE INTO run_normalized_items (run_id, normalized_item_id) VALUES (?, ?)", (run_id, identifier)
            )
    return len(rows)
