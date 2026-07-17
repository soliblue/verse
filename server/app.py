import hashlib
import hmac
import json
import mimetypes
import re
import sqlite3
import subprocess
import threading
from collections.abc import Callable
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import unquote, urlsplit

from db.connection import database, json_text, transaction, utc_now
from db.content import hydrate_cover_urls
from db.repository import (
    current_edition,
    current_explore,
    edition,
    edition_summaries,
    queue_deep_dive,
    record_event_feedback,
    record_feedback,
    record_venue_feedback,
    related_stories,
    replace_topics,
    topics,
    watched_venues,
)
from etl.content import write_preferences, write_preferences_markdown
from server.config import APIError, ServerConfig


class VerseHTTPServer(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True

    def __init__(self, address: tuple[str, int], config: ServerConfig):
        self.config = config
        self.preferences_lock = threading.Lock()
        self.guidance_lock = threading.Lock()
        super().__init__(address, VerseHandler)


class VerseHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "Verse/0"
    sys_version = ""

    def do_GET(self) -> None:
        self.handle_request("GET")

    def do_POST(self) -> None:
        self.handle_request("POST")

    def do_PUT(self) -> None:
        self.handle_request("PUT")

    def do_DELETE(self) -> None:
        self.handle_request("DELETE")

    def do_PATCH(self) -> None:
        self.handle_request("PATCH")

    def do_OPTIONS(self) -> None:
        origin = self.headers.get("Origin")
        if origin not in self.server.config.cors_origins:
            self.send_error_payload(HTTPStatus.NOT_FOUND, "not_found", "route not found")
            return
        self.send_response(HTTPStatus.NO_CONTENT)
        self.send_header("Access-Control-Allow-Origin", origin)
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Authorization, Content-Type, Idempotency-Key")
        self.send_header("Access-Control-Max-Age", "600")
        self.send_header("Vary", "Origin")
        self.send_header("Content-Length", "0")
        self.end_headers()

    def handle_request(self, method: str) -> None:
        try:
            path = urlsplit(self.path).path
            if path.startswith("/v1/assets/"):
                self.require_method(method, "GET")
                self.authorize()
                self.send_asset(path)
                return
            status, payload = self.dispatch(method)
            self.send_json(status, payload)
        except APIError as error:
            self.send_error_payload(error.status, error.code, error.message)
        except (json.JSONDecodeError, UnicodeDecodeError):
            self.send_error_payload(HTTPStatus.BAD_REQUEST, "invalid_json", "request body must contain valid UTF-8 JSON")
        except ValueError as error:
            self.send_error_payload(HTTPStatus.BAD_REQUEST, "invalid_request", str(error))
        except LookupError as error:
            self.send_error_payload(HTTPStatus.NOT_FOUND, "not_found", str(error))
        except sqlite3.Error:
            self.log_error("database request failed")
            self.send_error_payload(HTTPStatus.INTERNAL_SERVER_ERROR, "database_error", "database request failed")
        except Exception:
            self.log_error("unexpected request failure")
            self.send_error_payload(HTTPStatus.INTERNAL_SERVER_ERROR, "internal_error", "unexpected server error")

    def dispatch(self, method: str) -> tuple[int, object]:
        path = urlsplit(self.path).path
        if path == "/health":
            self.require_method(method, "GET")
            return HTTPStatus.OK, self.health()
        if not path.startswith("/v1/"):
            raise APIError(HTTPStatus.NOT_FOUND, "not_found", "route not found")
        self.authorize()
        if path == "/v1/edition/today":
            self.require_method(method, "GET")
            with database(self.server.config.database_path, readonly=True) as connection:
                payload = current_edition(connection)
                if payload is not None:
                    payload = hydrate_cover_urls(connection, payload, self.server.config.public_base_url)
            if payload is None:
                raise APIError(HTTPStatus.NOT_FOUND, "edition_not_found", "no current edition is available")
            return HTTPStatus.OK, payload
        if path == "/v1/editions":
            self.require_method(method, "GET")
            with database(self.server.config.database_path, readonly=True) as connection:
                return HTTPStatus.OK, edition_summaries(connection)
        if path.startswith("/v1/editions/"):
            self.require_method(method, "GET")
            edition_id = unquote(path.removeprefix("/v1/editions/"))
            if not edition_id or "/" in edition_id or len(edition_id) > 200:
                raise APIError(HTTPStatus.NOT_FOUND, "not_found", "route not found")
            with database(self.server.config.database_path, readonly=True) as connection:
                payload = edition(connection, edition_id)
                if payload is not None:
                    payload = hydrate_cover_urls(connection, payload, self.server.config.public_base_url)
            if payload is None:
                raise APIError(HTTPStatus.NOT_FOUND, "edition_not_found", "edition not found")
            return HTTPStatus.OK, payload
        if path == "/v1/topics":
            if method == "GET":
                with database(self.server.config.database_path, readonly=True) as connection:
                    return HTTPStatus.OK, topics(connection)
            if method == "PUT":
                request = self.read_json_object()
                write_preferences(self.server.config.content_path / "preferences.md", request)
                with database(self.server.config.database_path) as connection:
                    return HTTPStatus.OK, replace_topics(connection, request)
            self.require_method(method, "GET", "PUT")
        if path == "/v1/preferences":
            self.require_method(method, "GET", "PUT")
            preferences = self.server.config.content_path / "preferences.md"
            with self.server.preferences_lock:
                if method == "GET":
                    if not preferences.is_file():
                        raise LookupError("preferences not found")
                    return HTTPStatus.OK, {"markdown": preferences.read_text(encoding="utf-8")}
                request = self.read_json_object()
                previous = preferences.read_text(encoding="utf-8") if preferences.is_file() else None
                payload = write_preferences_markdown(preferences, request.get("markdown"))
                try:
                    with database(self.server.config.database_path) as connection:
                        replace_topics(connection, payload)
                except Exception:
                    if previous is None:
                        preferences.unlink(missing_ok=True)
                    else:
                        write_preferences_markdown(preferences, previous)
                    raise
                return HTTPStatus.OK, {"markdown": preferences.read_text(encoding="utf-8")}
        if path.startswith("/v1/guidance/"):
            self.require_method(method, "GET", "PUT")
            kind = path.removeprefix("/v1/guidance/")
            if kind not in {"articles", "events"}:
                raise APIError(HTTPStatus.NOT_FOUND, "not_found", "route not found")
            guidance = self.server.config.content_path / "prompts" / f"{kind}.md"
            with self.server.guidance_lock:
                if method == "GET":
                    if not guidance.is_file():
                        raise LookupError("guidance not found")
                    return HTTPStatus.OK, {"kind": kind, "markdown": guidance.read_text(encoding="utf-8")}
                request = self.read_json_object()
                markdown = request.get("markdown")
                if not isinstance(markdown, str) or not markdown.strip():
                    raise ValueError("markdown must be a non-empty string")
                if len(markdown.encode("utf-8")) > 32_768:
                    raise ValueError("markdown is too large")
                guidance.parent.mkdir(parents=True, exist_ok=True)
                guidance.write_text(markdown.rstrip() + "\n", encoding="utf-8")
                return HTTPStatus.OK, {"kind": kind, "markdown": guidance.read_text(encoding="utf-8")}
        if path.startswith("/v1/runs/"):
            self.require_method(method, "POST")
            self.read_json_object()
            kind = path.removeprefix("/v1/runs/")
            if kind not in {"articles", "events"}:
                raise APIError(HTTPStatus.NOT_FOUND, "not_found", "route not found")
            command = self.server.config.nightjar_trigger
            if command is None:
                raise APIError(HTTPStatus.SERVICE_UNAVAILABLE, "run_unavailable", "Nightjar runs are not configured")
            result = subprocess.run(
                [value.replace("{job}", kind) for value in command],
                capture_output=True,
                text=True,
                timeout=10,
            )
            if result.returncode != 0:
                raise APIError(HTTPStatus.CONFLICT, "run_not_started", "Nightjar is already running or unavailable")
            return HTTPStatus.ACCEPTED, {"kind": kind, "status": "started"}
        if path == "/v1/explore":
            self.require_method(method, "GET")
            with database(self.server.config.database_path, readonly=True) as connection:
                payload = current_explore(connection)
            if payload is None:
                raise APIError(HTTPStatus.NOT_FOUND, "explore_not_found", "no current Explore snapshot is available")
            return HTTPStatus.OK, payload
        if path == "/v1/venues":
            self.require_method(method, "GET")
            with database(self.server.config.database_path, readonly=True) as connection:
                return HTTPStatus.OK, watched_venues(connection)
        if path == "/v1/venue-feedback":
            self.require_method(method, "POST")
            request = self.read_json_object()
            venue_id = request.get("venue_id")
            if not isinstance(venue_id, str) or not venue_id or len(venue_id) > 200:
                raise ValueError("venue_id must be a non-empty string")
            with database(self.server.config.database_path) as connection:
                return self.idempotent_write(
                    connection,
                    path,
                    request,
                    HTTPStatus.OK,
                    lambda: {
                        "venue_id": venue_id,
                        **record_venue_feedback(
                            connection,
                            venue_id,
                            request.get("kind"),
                            request.get("value"),
                        ),
                    },
                )
        if path.startswith("/v1/stories/") and path.endswith("/related"):
            self.require_method(method, "GET")
            story_id = unquote(path.removeprefix("/v1/stories/").removesuffix("/related"))
            if not story_id or "/" in story_id or len(story_id) > 200:
                raise APIError(HTTPStatus.NOT_FOUND, "not_found", "route not found")
            with database(self.server.config.database_path, readonly=True) as connection:
                return HTTPStatus.OK, related_stories(connection, story_id)
        if path == "/v1/feedback":
            self.require_method(method, "POST")
            request = self.read_json_object()
            story_id = request.get("story_id")
            if not isinstance(story_id, str) or not story_id or len(story_id) > 200:
                raise ValueError("story_id must be a non-empty string")
            with database(self.server.config.database_path) as connection:
                return self.idempotent_write(
                    connection,
                    path,
                    request,
                    HTTPStatus.OK,
                    lambda: {
                        "story_id": story_id,
                        "feedback": record_feedback(
                            connection, story_id, request.get("kind"), request.get("value")
                        ),
                    },
                )
        if path == "/v1/deep-dives":
            self.require_method(method, "POST")
            request = self.read_json_object()
            story_id = request.get("story_id")
            if not isinstance(story_id, str) or not story_id or len(story_id) > 200:
                raise ValueError("story_id must be a non-empty string")
            with database(self.server.config.database_path) as connection:
                return self.idempotent_write(
                    connection,
                    path,
                    request,
                    HTTPStatus.ACCEPTED,
                    lambda: {"story_id": story_id, "deep_dive": queue_deep_dive(connection, story_id)},
                )
        if path == "/v1/event-feedback":
            self.require_method(method, "POST")
            request = self.read_json_object()
            event_id = request.get("event_id")
            occurrence_id = request.get("occurrence_id")
            if not isinstance(event_id, str) or not event_id or len(event_id) > 200:
                raise ValueError("event_id must be a non-empty string")
            if occurrence_id is not None and (
                not isinstance(occurrence_id, str) or not occurrence_id or len(occurrence_id) > 200
            ):
                raise ValueError("occurrence_id must be a non-empty string when supplied")
            with database(self.server.config.database_path) as connection:
                return self.idempotent_write(
                    connection,
                    path,
                    request,
                    HTTPStatus.OK,
                    lambda: {
                        "event_id": event_id,
                        "occurrence_id": occurrence_id,
                        "feedback": record_event_feedback(
                            connection,
                            event_id,
                            occurrence_id,
                            request.get("kind"),
                            request.get("value"),
                        ),
                    },
                )
        raise APIError(HTTPStatus.NOT_FOUND, "not_found", "route not found")

    def idempotent_write(
        self,
        connection: sqlite3.Connection,
        path: str,
        request: dict,
        status: int,
        action: Callable[[], dict],
    ) -> tuple[int, dict]:
        key = self.headers.get("Idempotency-Key")
        if key is None:
            return status, action()
        if not key.strip() or len(key) > 200:
            raise ValueError("Idempotency-Key must contain between 1 and 200 characters")
        request_hash = hashlib.sha256(json_text(request).encode()).hexdigest()
        with transaction(connection, immediate=True):
            existing = connection.execute(
                "SELECT method, path, request_hash, status, response_json "
                "FROM idempotency_keys WHERE key = ?",
                (key,),
            ).fetchone()
            if existing is not None:
                if (
                    existing["method"] != "POST"
                    or existing["path"] != path
                    or existing["request_hash"] != request_hash
                ):
                    raise APIError(
                        HTTPStatus.CONFLICT,
                        "idempotency_conflict",
                        "Idempotency-Key was already used for another request",
                    )
                return existing["status"], json.loads(existing["response_json"])
            response = action()
            connection.execute(
                "INSERT INTO idempotency_keys "
                "(key, method, path, request_hash, status, response_json, created_at) "
                "VALUES (?, 'POST', ?, ?, ?, ?, ?)",
                (key, path, request_hash, status, json_text(response), utc_now()),
            )
        return status, response

    def require_method(self, actual: str, *allowed: str) -> None:
        if actual not in allowed:
            raise APIError(HTTPStatus.METHOD_NOT_ALLOWED, "method_not_allowed", f"method must be {' or '.join(allowed)}")

    def authorize(self) -> None:
        secret = self.server.config.device_secret
        if secret is None:
            if self.server.config.allow_unauthenticated:
                return
            raise APIError(
                HTTPStatus.SERVICE_UNAVAILABLE,
                "authentication_not_configured",
                "private API authentication is not configured",
            )
        supplied = self.headers.get("Authorization", "")
        expected = f"Bearer {secret}"
        if not hmac.compare_digest(supplied.encode(), expected.encode()):
            raise APIError(HTTPStatus.UNAUTHORIZED, "unauthorized", "a valid bearer token is required")

    def read_json_object(self) -> dict:
        if not self.headers.get("Content-Type", "").lower().startswith("application/json"):
            raise APIError(HTTPStatus.UNSUPPORTED_MEDIA_TYPE, "unsupported_media_type", "Content-Type must be application/json")
        raw_length = self.headers.get("Content-Length")
        if raw_length is None:
            raise APIError(HTTPStatus.LENGTH_REQUIRED, "length_required", "Content-Length is required")
        try:
            length = int(raw_length)
        except ValueError:
            raise APIError(HTTPStatus.BAD_REQUEST, "invalid_content_length", "Content-Length must be an integer") from None
        if length < 0:
            raise APIError(HTTPStatus.BAD_REQUEST, "invalid_content_length", "Content-Length must not be negative")
        if length > self.server.config.maximum_body_bytes:
            raise APIError(HTTPStatus.REQUEST_ENTITY_TOO_LARGE, "request_too_large", "request body is too large")
        payload = json.loads(self.rfile.read(length).decode("utf-8"))
        if not isinstance(payload, dict):
            raise ValueError("request body must be a JSON object")
        return payload

    def health(self) -> dict:
        with database(self.server.config.database_path, readonly=True) as connection:
            connection.execute("SELECT 1").fetchone()
            row = connection.execute("SELECT value FROM settings WHERE key = 'current_edition_id'").fetchone()
        return {"status": "ok", "database": "ok", "current_edition_id": None if row is None else row["value"]}

    def send_asset(self, request_path: str) -> None:
        relative = unquote(request_path.removeprefix("/v1/assets/"))
        parts = relative.split("/")
        if (
            len(parts) != 3
            or parts[1] != "assets"
            or any(not part or part in {".", ".."} or "\\" in part for part in parts)
            or not re.fullmatch(r"[a-zA-Z0-9._-]+", parts[0])
            or not re.fullmatch(r"[a-zA-Z0-9._-]+\.(?:png|jpe?g|webp)", parts[2], re.IGNORECASE)
        ):
            raise APIError(HTTPStatus.NOT_FOUND, "asset_not_found", "asset not found")
        root = self.server.config.content_path.resolve()
        path = (root / "editions" / parts[0] / "assets" / parts[2]).resolve()
        if root not in path.parents or not path.is_file():
            raise APIError(HTTPStatus.NOT_FOUND, "asset_not_found", "asset not found")
        size = path.stat().st_size
        if size > self.server.config.maximum_asset_bytes:
            raise APIError(HTTPStatus.REQUEST_ENTITY_TOO_LARGE, "asset_too_large", "asset is too large")
        media_type = mimetypes.guess_type(path.name)[0]
        if media_type not in {"image/png", "image/jpeg", "image/webp"}:
            raise APIError(HTTPStatus.NOT_FOUND, "asset_not_found", "asset not found")
        body = path.read_bytes()
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", media_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "private, max-age=86400, immutable")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(body)

    def send_error_payload(self, status: int, code: str, message: str) -> None:
        self.close_connection = True
        self.send_json(status, {"error": {"code": code, "message": message}})

    def send_json(self, status: int, payload: object) -> None:
        body = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Content-Security-Policy", "default-src 'none'")
        if status == HTTPStatus.UNAUTHORIZED:
            self.send_header("WWW-Authenticate", 'Bearer realm="Verse"')
        origin = self.headers.get("Origin")
        if origin in self.server.config.cors_origins:
            self.send_header("Access-Control-Allow-Origin", origin)
            self.send_header("Vary", "Origin")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format: str, *args: object) -> None:
        super().log_message(format, *args)


def create_server(config: ServerConfig, host: str = "127.0.0.1", port: int = 8787) -> VerseHTTPServer:
    return VerseHTTPServer((host, port), config)
