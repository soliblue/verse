import fcntl
import json
import os
import sqlite3
from contextlib import contextmanager, nullcontext
from collections.abc import Iterator
from datetime import UTC, datetime
from pathlib import Path


def default_database_path() -> Path:
    return Path(os.environ.get("VERSE_DB_PATH", "db/verse.sqlite"))


def utc_now() -> str:
    return datetime.now(UTC).isoformat(timespec="seconds").replace("+00:00", "Z")


def json_text(value: object) -> str:
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"), sort_keys=True)


def connect(path: str | Path | None = None, readonly: bool = False) -> sqlite3.Connection:
    database_path = Path(path) if path is not None else default_database_path()
    if not readonly:
        database_path.parent.mkdir(parents=True, exist_ok=True)
    target = f"file:{database_path}?mode=ro" if readonly else str(database_path)
    with (nullcontext() if readonly else database_path.open("a+b")) as lock:
        if lock is not None:
            fcntl.flock(lock, fcntl.LOCK_EX)
        connection = sqlite3.connect(target, uri=readonly, timeout=5)
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA foreign_keys = ON")
        connection.execute("PRAGMA busy_timeout = 5000")
        if not readonly:
            connection.execute("PRAGMA journal_mode = WAL")
            connection.execute("PRAGMA synchronous = NORMAL")
    return connection


@contextmanager
def database(path: str | Path | None = None, readonly: bool = False) -> Iterator[sqlite3.Connection]:
    connection = connect(path, readonly)
    try:
        yield connection
    finally:
        connection.close()


@contextmanager
def transaction(connection: sqlite3.Connection, immediate: bool = False) -> Iterator[sqlite3.Connection]:
    if connection.in_transaction:
        yield connection
        return
    connection.execute("BEGIN IMMEDIATE" if immediate else "BEGIN")
    try:
        yield connection
    except Exception:
        connection.rollback()
        raise
    else:
        connection.commit()
