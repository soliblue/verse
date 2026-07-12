import hashlib
import os
import re
import sqlite3
from pathlib import Path

from db.connection import connect, utc_now
from db.environment import load_environment


MIGRATIONS_DIRECTORY = Path(__file__).with_name("migrations")
MIGRATION_NAME = re.compile(r"^(\d{3})_[a-z0-9_]+\.sql$")


def migration_files(directory: Path = MIGRATIONS_DIRECTORY) -> list[Path]:
    files = sorted(path for path in directory.glob("*.sql") if MIGRATION_NAME.match(path.name))
    versions = [int(MIGRATION_NAME.match(path.name).group(1)) for path in files]
    if len(versions) != len(set(versions)):
        raise ValueError("migration versions must be unique")
    return files


def statements(sql: str) -> list[str]:
    result = []
    pending = ""
    for line in sql.splitlines(keepends=True):
        pending += line
        if sqlite3.complete_statement(pending):
            if pending.strip():
                result.append(pending)
            pending = ""
    if pending.strip():
        raise ValueError("migration ends with an incomplete statement")
    return result


def migrate(connection: sqlite3.Connection, directory: Path = MIGRATIONS_DIRECTORY) -> list[int]:
    connection.execute(
        "CREATE TABLE IF NOT EXISTS schema_migrations (version INTEGER PRIMARY KEY, filename TEXT NOT NULL, checksum TEXT NOT NULL, applied_at TEXT NOT NULL)"
    )
    connection.commit()
    completed = []
    for path in migration_files(directory):
        version = int(MIGRATION_NAME.match(path.name).group(1))
        sql = path.read_text(encoding="utf-8")
        checksum = hashlib.sha256(sql.encode()).hexdigest()
        with connection:
            connection.execute("BEGIN IMMEDIATE")
            applied = connection.execute(
                "SELECT filename, checksum FROM schema_migrations WHERE version = ?", (version,)
            ).fetchone()
            if applied is not None:
                if applied["filename"] != path.name or applied["checksum"] != checksum:
                    raise RuntimeError(f"applied migration {version:03d} does not match {path.name}")
                continue
            for statement in statements(sql):
                connection.execute(statement)
            connection.execute(
                "INSERT INTO schema_migrations (version, filename, checksum, applied_at) VALUES (?, ?, ?, ?)",
                (version, path.name, checksum, utc_now()),
            )
        completed.append(version)
    return completed


def main() -> int:
    os.umask(0o077)
    load_environment()
    connection = connect()
    completed = migrate(connection)
    connection.close()
    print("applied=" + (",".join(f"{version:03d}" for version in completed) if completed else "none"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
