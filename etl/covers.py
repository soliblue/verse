import hashlib
import json
import os
import shlex
import struct
import subprocess
import zlib
from pathlib import Path

from db.connection import utc_now


DEFAULT_WIDTH = 1122
DEFAULT_HEIGHT = 1402
COVER_ENVIRONMENT_KEYS = {
    "HOME",
    "LANG",
    "LC_ALL",
    "OPENAI_API_KEY",
    "PATH",
    "SSL_CERT_DIR",
    "SSL_CERT_FILE",
    "TMPDIR",
}


def cover_prompt(story: dict) -> str:
    topics = ", ".join(story.get("topic_ids", [])[:3]).replace("-", " ")
    return (
        "Minimal abstract pixel universe cover with generous negative space, no text, no logos, "
        f"no faces. Quiet spatial form inspired by {story['title']} and {topics or story['kind']}."
    )


def cover_environment() -> dict[str, str]:
    return {key: os.environ[key] for key in COVER_ENVIRONMENT_KEYS if os.environ.get(key)}


def png_chunk(kind: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)


def fallback_png(path: Path, story_id: str, width: int = DEFAULT_WIDTH, height: int = DEFAULT_HEIGHT) -> None:
    digest = hashlib.sha256(story_id.encode()).digest()
    background = tuple(244 + byte % 10 for byte in digest[:3])
    accent = tuple(30 + byte % 170 for byte in digest[3:6])
    second = tuple(20 + byte % 110 for byte in digest[6:9])
    block = max(20, min(width, height) // 24)
    points = [
        (2 + digest[index] % 17, 2 + digest[index + 1] % 11, 1 + digest[index + 2] % 3, index % 2)
        for index in range(9, 30, 3)
    ]
    rows = bytearray()
    for y in range(height):
        rows.append(0)
        by = y // block
        for x in range(width):
            bx = x // block
            color = background
            for px, py, size, palette in points:
                if px <= bx < px + size and py <= by < py + size:
                    color = accent if palette == 0 else second
                    break
            rows.extend(color)
    header = b"\x89PNG\r\n\x1a\n"
    data = png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
    data += png_chunk(b"IDAT", zlib.compress(bytes(rows), level=9))
    data += png_chunk(b"IEND", b"")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(header + data)


def generated_cover(path: Path, story: dict, prompt: str, width: int, height: int) -> dict | None:
    configured = os.environ.get("VERSE_COVER_COMMAND")
    if not configured:
        return None
    command = [
        part.format(output=str(path), story_id=story["id"], width=width, height=height)
        for part in shlex.split(configured)
    ]
    try:
        result = subprocess.run(
            command,
            env=cover_environment(),
            input=prompt,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=int(os.environ.get("VERSE_COVER_TIMEOUT_SECONDS", "300")),
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if (
        result.returncode != 0
        or not path.is_file()
        or path.stat().st_size == 0
        or path.read_bytes()[:8] != b"\x89PNG\r\n\x1a\n"
    ):
        path.unlink(missing_ok=True)
        return None
    return {
        "provider": command[0],
        "model": os.environ.get("VERSE_COVER_MODEL", "unknown"),
        "is_fallback": False,
        "stdout": result.stdout[-1000:],
        "stderr": result.stderr[-1000:],
    }


def prepare_cover(directory: Path, story: dict, width: int = DEFAULT_WIDTH, height: int = DEFAULT_HEIGHT) -> dict:
    prompt = cover_prompt(story)
    path = directory / f"{story['id']}.png"
    generated = generated_cover(path, story, prompt, width, height)
    if generated is None:
        fallback_png(path, story["id"], width, height)
        generated = {"provider": "verse", "model": "pixel-field-v1", "is_fallback": True}
    metadata = {
        "story_id": story["id"],
        "prompt": prompt,
        "provider": generated["provider"],
        "model": generated["model"],
        "width": width,
        "height": height,
        "is_fallback": generated["is_fallback"],
        "generated_at": utc_now(),
    }
    metadata_path = path.with_suffix(".cover.json")
    metadata_path.write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return {**metadata, "path": path}
