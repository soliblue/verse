import sqlite3

from db.connection import utc_now
from etl.validation import validate_topics


def topics(connection: sqlite3.Connection) -> dict:
    rows = connection.execute(
        "SELECT id, name, kind, description, is_enabled, position FROM topics ORDER BY position, id"
    )
    return {
        "topics": [
            {
                "id": row["id"],
                "name": row["name"],
                "kind": row["kind"],
                "description": row["description"],
                "is_enabled": bool(row["is_enabled"]),
                "position": row["position"],
            }
            for row in rows
        ]
    }


def replace_topics(connection: sqlite3.Connection, payload: dict) -> dict:
    validate_topics(payload)
    now = utc_now()
    with connection:
        connection.execute("BEGIN IMMEDIATE")
        connection.execute("DELETE FROM topics")
        connection.executemany(
            "INSERT INTO topics (id, name, kind, description, is_enabled, position, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            [
                (
                    topic["id"],
                    topic["name"],
                    topic["kind"],
                    topic["description"],
                    int(topic["is_enabled"]),
                    topic["position"],
                    now,
                    now,
                )
                for topic in payload["topics"]
            ],
        )
    return topics(connection)
