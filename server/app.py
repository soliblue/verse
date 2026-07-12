import hashlib
import hmac
import json
import sqlite3
from collections.abc import Callable
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import unquote, urlsplit

from db.connection import database, json_text, transaction, utc_now
from db.repository import (
    current_edition,
    edition,
    edition_summaries,
    queue_deep_dive,
    record_feedback,
    replace_topics,
    topics,
)
from server.config import APIError, ServerConfig


class MorrowHTTPServer(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True

    def __init__(self, address: tuple[str, int], config: ServerConfig):
        self.config = config
        super().__init__(address, MorrowHandler)


class MorrowHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "Morrow/0"
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
            if payload is None:
                raise APIError(HTTPStatus.NOT_FOUND, "edition_not_found", "edition not found")
            return HTTPStatus.OK, payload
        if path == "/v1/topics":
            if method == "GET":
                with database(self.server.config.database_path, readonly=True) as connection:
                    return HTTPStatus.OK, topics(connection)
            if method == "PUT":
                with database(self.server.config.database_path) as connection:
                    return HTTPStatus.OK, replace_topics(connection, self.read_json_object())
            self.require_method(method, "GET", "PUT")
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
            self.send_header("WWW-Authenticate", 'Bearer realm="Morrow"')
        origin = self.headers.get("Origin")
        if origin in self.server.config.cors_origins:
            self.send_header("Access-Control-Allow-Origin", origin)
            self.send_header("Vary", "Origin")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format: str, *args: object) -> None:
        super().log_message(format, *args)


def create_server(config: ServerConfig, host: str = "127.0.0.1", port: int = 8787) -> MorrowHTTPServer:
    return MorrowHTTPServer((host, port), config)
