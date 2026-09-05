import json
import sqlite3
from contextlib import contextmanager
from datetime import datetime, timezone
from uuid import uuid4


def timestamp():
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


class Store:
    def __init__(self, path):
        self.path = path
        path.parent.mkdir(parents=True, exist_ok=True)
        with self.connection() as connection:
            connection.execute("PRAGMA journal_mode=WAL")
            connection.execute("CREATE TABLE IF NOT EXISTS transcriptions (id TEXT PRIMARY KEY, state TEXT NOT NULL, created_at TEXT NOT NULL, payload TEXT NOT NULL)")
        path.chmod(0o600)

    @contextmanager
    def connection(self):
        connection = sqlite3.connect(self.path, timeout=30)
        try:
            with connection:
                yield connection
        finally:
            connection.close()

    def create(self, filename, model, language, duration, job_id=None):
        now = timestamp()
        job = dict(id=job_id or uuid4().hex, filename=filename, state="queued", model=model,
                   language=language, detected_language=None, text="", segments=[],
                   duration_seconds=duration, error=None, created_at=now, updated_at=now)
        with self.connection() as connection:
            connection.execute("INSERT INTO transcriptions VALUES (?, ?, ?, ?)",
                               (job["id"], job["state"], now, json.dumps(job)))
        return job

    def list(self):
        with self.connection() as connection:
            return [json.loads(row[0]) for row in connection.execute("SELECT payload FROM transcriptions ORDER BY created_at DESC")]

    def get(self, job_id):
        with self.connection() as connection:
            row = connection.execute("SELECT payload FROM transcriptions WHERE id = ?", (job_id,)).fetchone()
        return json.loads(row[0]) if row else None

    def update(self, job_id, **values):
        with self.connection() as connection:
            connection.execute("BEGIN IMMEDIATE")
            row = connection.execute("SELECT payload FROM transcriptions WHERE id = ?", (job_id,)).fetchone()
            if row is None:
                return
            job = json.loads(row[0])
            job.update(values, updated_at=timestamp())
            connection.execute("UPDATE transcriptions SET state=?, payload=? WHERE id=?", (job["state"], json.dumps(job), job_id))

    def delete(self, job_id):
        with self.connection() as connection:
            return connection.execute("DELETE FROM transcriptions WHERE id=?", (job_id,)).rowcount > 0

    def recover(self):
        for job in self.list():
            if job["state"] == "transcribing":
                self.update(job["id"], state="queued", error=None)
