import hmac
import json
import math
import re
import shutil
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlsplit
from uuid import uuid4

from speech_server.engine import inspect_audio
from speech_server.store import Store
from speech_server.worker import Worker


LANGUAGES = ["auto", "en", "de", "ar", "fr", "es", "it", "pt", "nl", "tr", "ru", "uk", "zh", "ja", "ko", "hi", "pl", "sv", "da", "no", "fi", "el", "he", "fa", "ur", "id", "vi", "th"]


class APIError(Exception):
    def __init__(self, status, message):
        self.status = status
        super().__init__(message)


class Server(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, address, config):
        self.config = config
        config.audio.mkdir(parents=True, exist_ok=True)
        config.audio.chmod(0o700)
        self.store = Store(config.database)
        self.worker = Worker(config, self.store)
        self.upload_lock = threading.Semaphore(2)
        self.request_slots = threading.Semaphore(16)
        self.reservation_lock = threading.Lock()
        self.reserved_bytes = 0
        self.reserved_jobs = 0
        super().__init__(address, Handler)

    def process_request(self, request, client_address):
        if not self.request_slots.acquire(blocking=False):
            self.shutdown_request(request)
            return
        super().process_request(request, client_address)

    def process_request_thread(self, request, client_address):
        try:
            super().process_request_thread(request, client_address)
        finally:
            self.request_slots.release()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def do_GET(self):
        self.dispatch()

    def do_POST(self):
        self.dispatch()

    def do_DELETE(self):
        self.dispatch()

    def dispatch(self):
        self.connection.settimeout(60)
        try:
            self.route()
        except APIError as error:
            self.respond(error.status, {"error": str(error)})
        except (BrokenPipeError, ConnectionResetError):
            self.close_connection = True
        except Exception:
            self.respond(500, {"error": "The request could not be completed"})

    def respond(self, status, value=None):
        data = json.dumps(value, ensure_ascii=False).encode() if value is not None else b""
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def route(self):
        parsed = urlsplit(self.path)
        path = parsed.path.rstrip("/")
        if path == "/health" and self.command == "GET":
            self.respond(200, {"status": "ok"})
            return
        expected = "Bearer " + self.server.config.secret
        if not hmac.compare_digest(self.headers.get("Authorization", "").encode(), expected.encode()):
            raise APIError(401, "Enter your device token in Settings")
        if path == "/v1/config" and self.command == "GET":
            config = self.server.config
            self.respond(200, dict(default_model=config.default_model, models=list(config.models), languages=LANGUAGES, max_upload_bytes=config.maximum_upload, max_duration_seconds=config.maximum_duration))
            return
        if path == "/v1/transcriptions":
            if self.command == "GET":
                self.respond(200, {"transcriptions": self.server.store.list()})
                return
            if self.command == "POST":
                if not self.server.upload_lock.acquire(blocking=False):
                    raise APIError(429, "Another upload is in progress. Try again shortly.")
                try:
                    self.upload(parse_qs(parsed.query))
                finally:
                    self.server.upload_lock.release()
                return
        match = re.fullmatch(r"/v1/transcriptions/([a-f0-9]{32})(/audio)?", path)
        if match:
            job_id, audio = match.groups()
            job = self.server.store.get(job_id)
            if job is None:
                raise APIError(404, "Transcription not found")
            source = self.server.config.audio / job_id
            if self.command == "DELETE" and not audio:
                self.server.store.delete(job_id)
                source.unlink(missing_ok=True)
                self.respond(204)
                return
            if self.command == "GET" and not audio:
                self.respond(200, job)
                return
            if self.command == "GET" and audio:
                if not source.is_file():
                    raise APIError(404, "Recording not found")
                with source.open("rb") as stream:
                    self.send_response(200)
                    self.send_header("Content-Type", "application/octet-stream")
                    self.send_header("Content-Length", str(source.stat().st_size))
                    self.send_header("Cache-Control", "no-store")
                    self.end_headers()
                    shutil.copyfileobj(stream, self.wfile)
                return
        raise APIError(404, "Not found")

    def upload(self, query):
        config = self.server.config
        if self.headers.get("Transfer-Encoding"):
            raise APIError(400, "Use a fixed Content-Length")
        length = self.headers.get("Content-Length", "")
        if not length.isdigit() or int(length) == 0:
            raise APIError(400, "Upload an audio file")
        if int(length) > config.maximum_upload:
            raise APIError(413, "Audio files must be 50 MB or smaller")
        model = query.get("model", [config.default_model])[0]
        language = query.get("language", ["auto"])[0]
        if model not in config.models or language not in LANGUAGES:
            raise APIError(400, "Unsupported model or language")
        with self.server.reservation_lock:
            pending = sum(job["state"] in ("queued", "transcribing") for job in self.server.store.list())
            if pending + self.server.reserved_jobs >= 20:
                raise APIError(429, "The transcription queue is full")
            used = sum(entry.stat().st_size for entry in config.audio.iterdir() if entry.is_file())
            if used + self.server.reserved_bytes + int(length) > config.maximum_storage:
                raise APIError(507, "Recording storage is full. Delete old recordings first.")
            if shutil.disk_usage(config.audio).free < int(length) + 512 * 1024 * 1024:
                raise APIError(507, "The server needs more free storage")
            self.server.reserved_bytes += int(length)
            self.server.reserved_jobs += 1
        filename = Path(query.get("filename", ["Recording.m4a"])[0]).name[:200]
        job_id = uuid4().hex
        path = config.audio / job_id
        remaining = int(length)
        try:
            with path.open("xb") as stream:
                path.chmod(0o600)
                while remaining:
                    block = self.rfile.read(min(1024 * 1024, remaining))
                    if not block:
                        raise APIError(400, "The upload was interrupted")
                    stream.write(block)
                    remaining -= len(block)
            try:
                duration = inspect_audio(path)
            except Exception:
                raise APIError(400, "This file does not contain readable audio") from None
            if duration is not None and (not math.isfinite(duration) or duration <= 0 or duration > config.maximum_duration):
                raise APIError(400, "Recordings must be shorter than one hour")
            job = self.server.store.create(filename, model, language, duration, job_id)
        except Exception:
            path.unlink(missing_ok=True)
            raise
        finally:
            with self.server.reservation_lock:
                self.server.reserved_bytes -= int(length)
                self.server.reserved_jobs -= 1
        self.server.worker.wake.set()
        self.respond(202, job)
