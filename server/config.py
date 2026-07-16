import os
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlparse

from db.connection import default_database_path


@dataclass(frozen=True)
class ServerConfig:
    database_path: Path
    device_secret: str | None = None
    cors_origins: tuple[str, ...] = ()
    maximum_body_bytes: int = 65_536
    allow_unauthenticated: bool = False
    content_path: Path = Path("content")
    public_base_url: str | None = None
    maximum_asset_bytes: int = 10_485_760

    @classmethod
    def environment(cls) -> "ServerConfig":
        origins = tuple(origin.strip() for origin in os.environ.get("VERSE_CORS_ORIGINS", "").split(",") if origin.strip())
        secret = os.environ.get("VERSE_DEVICE_SECRET") or None
        allow_unauthenticated = os.environ.get("VERSE_ALLOW_UNAUTHENTICATED", "0") == "1"
        maximum = int(os.environ.get("VERSE_MAX_REQUEST_BYTES", "65536"))
        maximum_asset = int(os.environ.get("VERSE_MAX_ASSET_BYTES", "10485760"))
        public_base_url = os.environ.get("VERSE_PUBLIC_BASE_URL") or None
        if maximum < 1:
            raise ValueError("VERSE_MAX_REQUEST_BYTES must be positive")
        if secret is None and not allow_unauthenticated:
            raise ValueError(
                "VERSE_DEVICE_SECRET is required unless VERSE_ALLOW_UNAUTHENTICATED=1"
            )
        if secret is not None and (len(secret) < 24 or secret.startswith("replace-with-")):
            raise ValueError("VERSE_DEVICE_SECRET must contain at least 24 characters and cannot be a placeholder")
        if maximum_asset < 1:
            raise ValueError("VERSE_MAX_ASSET_BYTES must be positive")
        if public_base_url is not None:
            parsed = urlparse(public_base_url)
            if (
                parsed.scheme not in {"http", "https"}
                or not parsed.netloc
                or parsed.username
                or parsed.password
                or parsed.path not in {"", "/"}
                or parsed.query
                or parsed.fragment
            ):
                raise ValueError("VERSE_PUBLIC_BASE_URL must be an http or https origin")
            public_base_url = public_base_url.rstrip("/")
        return cls(
            default_database_path(),
            secret,
            origins,
            maximum,
            allow_unauthenticated,
            Path(os.environ.get("VERSE_CONTENT_DIR", "content")),
            public_base_url,
            maximum_asset,
        )


class APIError(Exception):
    def __init__(self, status: int, code: str, message: str):
        super().__init__(message)
        self.status = status
        self.code = code
        self.message = message
