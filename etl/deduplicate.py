import hashlib
import re
import sqlite3
import unicodedata


def title_key(title: str) -> str:
    folded = unicodedata.normalize("NFKD", title).encode("ascii", "ignore").decode().lower()
    words = re.findall(r"[a-z0-9]+", folded)
    return " ".join(words[:24])


def deduplicate_stage(connection: sqlite3.Connection, run_id: str) -> int:
    rows = connection.execute(
        "SELECT n.id, n.canonical_url, n.title, n.published_at, length(n.content) AS content_length FROM normalized_items n JOIN run_normalized_items r ON r.normalized_item_id = n.id WHERE r.run_id = ? ORDER BY n.published_at DESC, content_length DESC, n.id",
        (run_id,),
    ).fetchall()
    winners: dict[str, str] = {}
    with connection:
        connection.execute("DELETE FROM run_candidates WHERE run_id = ?", (run_id,))
        for row in rows:
            key_source = title_key(row["title"]) or row["canonical_url"]
            key = hashlib.sha256(key_source.encode()).hexdigest()
            duplicate_of = winners.get(key)
            winners.setdefault(key, row["id"])
            connection.execute(
                "INSERT INTO run_candidates (run_id, normalized_item_id, dedupe_key, duplicate_of, selected) VALUES (?, ?, ?, ?, 0)",
                (run_id, row["id"], key, duplicate_of),
            )
    return len(rows)
