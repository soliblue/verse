import argparse
import sqlite3
from pathlib import Path

from db.connection import transaction


def reset_article_editions(connection: sqlite3.Connection, keep_id: str | None = None) -> int:
    with transaction(connection, immediate=True):
        if keep_id is None:
            removed = connection.execute("SELECT count(*) FROM editions").fetchone()[0]
            connection.execute("DELETE FROM editions")
            connection.execute("DELETE FROM settings WHERE key = 'current_edition_id'")
        else:
            removed = connection.execute("SELECT count(*) FROM editions WHERE id <> ?", (keep_id,)).fetchone()[0]
            connection.execute("DELETE FROM editions WHERE id <> ?", (keep_id,))
            connection.execute(
                "INSERT INTO settings (key, value, updated_at) "
                "SELECT 'current_edition_id', id, updated_at FROM editions WHERE id = ? "
                "ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at",
                (keep_id,),
            )
    return removed


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--database", type=Path, default=Path("db/verse.sqlite"))
    parser.add_argument("--keep")
    args = parser.parse_args()
    connection = sqlite3.connect(args.database)
    connection.execute("PRAGMA foreign_keys = ON")
    print(f"removed={reset_article_editions(connection, args.keep)}")
    connection.close()


if __name__ == "__main__":
    main()
