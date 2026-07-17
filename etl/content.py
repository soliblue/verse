import hashlib
import json
import re
import shutil
import uuid
from copy import deepcopy
from pathlib import Path
from urllib.parse import quote

from etl.validation import complete_edition, validate_citations, validate_edition, validate_topics


IDENTIFIER = re.compile(r"^[a-zA-Z0-9][a-zA-Z0-9._-]{0,199}$")
LINK = re.compile(r"^- \[(.+)]\((https?://.+)\)$")


def content_root() -> Path:
    import os

    return Path(os.environ.get("VERSE_CONTENT_DIR", "content"))


def decode_scalar(value: str) -> object:
    stripped = value.strip()
    if not stripped:
        return ""
    if stripped[0] in {'"', "[", "{"} or stripped in {"true", "false", "null"} or re.fullmatch(
        r"-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?", stripped
    ):
        return json.loads(stripped)
    return stripped


def encode_scalar(value: object) -> str:
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"))


def parse_document(path: Path) -> tuple[dict, str]:
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    if not lines or lines[0] != "---":
        raise ValueError(f"{path} must begin with front matter")
    metadata = {}
    closing = None
    for index, line in enumerate(lines[1:], start=1):
        if line == "---":
            closing = index
            break
        key, separator, value = line.partition(":")
        if not separator or not re.fullmatch(r"[a-z][a-z0-9_]*", key):
            raise ValueError(f"invalid front matter at {path}:{index + 1}")
        if key in metadata:
            raise ValueError(f"duplicate front matter key {key} at {path}:{index + 1}")
        metadata[key] = decode_scalar(value)
    if closing is None:
        raise ValueError(f"{path} front matter is not closed")
    return metadata, "\n".join(lines[closing + 1 :]).strip() + "\n"


def render_document(metadata: dict, body: str) -> str:
    lines = ["---", *(f"{key}: {encode_scalar(value)}" for key, value in metadata.items()), "---", "", body.strip(), ""]
    return "\n".join(lines)


def require_identifier(value: object, path: str) -> str:
    if not isinstance(value, str) or not IDENTIFIER.fullmatch(value):
        raise ValueError(f"{path} must be a safe identifier")
    return value


def story_sections(body: str, path: Path) -> tuple[str, str, str, str, list[dict]]:
    lines = body.splitlines()
    if not lines or not lines[0].startswith("# "):
        raise ValueError(f"{path} must begin with a story title")
    title = lines[0][2:].strip()
    why_marker = "## Why this was selected"
    source_marker = "## Sources"
    if why_marker not in lines or source_marker not in lines:
        raise ValueError(f"{path} must contain selection and source sections")
    why_index = lines.index(why_marker)
    source_index = lines.index(source_marker)
    if not 0 < why_index < source_index:
        raise ValueError(f"{path} sections are out of order")
    article = lines[1:why_index]
    while article and not article[0].strip():
        article.pop(0)
    summary_lines = []
    while article and (article[0].startswith(">") or not article[0].strip()):
        line = article.pop(0)
        if line.startswith(">"):
            summary_lines.append(line.removeprefix(">").strip())
    summary = " ".join(summary_lines).strip()
    article_body = "\n".join(article).strip()
    why_selected = "\n".join(lines[why_index + 1 : source_index]).strip()
    citations = []
    for number, line in enumerate(lines[source_index + 1 :], start=source_index + 2):
        if not line.strip():
            continue
        link_part, separator, details = line.rpartition(" | ")
        if not separator:
            raise ValueError(f"invalid citation at {path}:{number}")
        link_part, separator, source_name = link_part.rpartition(" | ")
        match = LINK.fullmatch(link_part)
        if not separator or match is None:
            raise ValueError(f"invalid citation at {path}:{number}")
        citations.append(
            {
                "title": match.group(1),
                "url": match.group(2),
                "source_name": source_name,
                "published_at": None if details == "null" else details,
            }
        )
    if not title or not summary or not article_body or not why_selected or not citations:
        raise ValueError(f"{path} story content is incomplete")
    return title, summary, article_body, why_selected, citations


def cover_url(public_base_url: str | None, edition_name: str, cover: str | None) -> str | None:
    if cover is None:
        return None
    parts = Path(cover).parts
    if len(parts) != 2 or parts[0] != "assets" or Path(cover).is_absolute() or ".." in parts:
        raise ValueError("story cover must be inside the edition assets directory")
    if public_base_url is None:
        return None
    encoded = "/".join(quote(part, safe="") for part in (edition_name, *parts))
    return f"{public_base_url.rstrip('/')}/v1/assets/{encoded}"


def load_story(path: Path, edition_name: str, public_base_url: str | None = None) -> tuple[dict, dict]:
    metadata, body = parse_document(path)
    title, summary, article_body, why_selected, citations = story_sections(body, path)
    story_id = require_identifier(metadata.get("id"), f"{path}.id")
    cover = metadata.get("cover")
    if cover is not None and not isinstance(cover, str):
        raise ValueError(f"{path}.cover must be a string")
    if cover is not None and not (path.parent / cover).is_file():
        raise ValueError(f"{path}.cover does not exist")
    item = {
        "id": story_id,
        "kind": metadata.get("kind"),
        "topic_ids": metadata.get("topic_ids"),
        "title": title,
        "summary": summary,
        "body": article_body,
        "why_selected": " ".join(why_selected.splitlines()),
        "source_name": metadata.get("source_name"),
        "source_url": metadata.get("source_url"),
        "published_at": metadata.get("published_at"),
        "reading_minutes": metadata.get("reading_minutes"),
        "image_url": cover_url(public_base_url, edition_name, cover),
        "citations": citations,
        "related_story_ids": metadata.get("related_story_ids", []),
        "related_event_ids": metadata.get("related_event_ids", []),
    }
    index = {
        "story_id": story_id,
        "path": path,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "cover_path": None if cover is None else f"editions/{edition_name}/{cover}",
        "cover_prompt": metadata.get("cover_prompt"),
        "cover_model": metadata.get("cover_model"),
        "cover_width": metadata.get("cover_width"),
        "cover_height": metadata.get("cover_height"),
        "cover_is_fallback": bool(metadata.get("cover_fallback", False)),
    }
    return item, index


def load_edition(path: Path, public_base_url: str | None = None) -> tuple[dict, dict]:
    metadata, body = parse_document(path)
    lines = body.splitlines()
    if not lines or not lines[0].startswith("# "):
        raise ValueError(f"{path} must begin with an edition title")
    title = lines[0][2:].strip()
    dek = "\n".join(lines[1:]).strip()
    edition_id = require_identifier(metadata.get("id"), f"{path}.id")
    stories = metadata.get("stories")
    if not isinstance(stories, list) or any(not isinstance(value, str) for value in stories):
        raise ValueError(f"{path}.stories must be a string array")
    items = []
    indexes = []
    for position, filename in enumerate(stories, start=1):
        relative = Path(filename)
        if relative.is_absolute() or len(relative.parts) != 1 or relative.suffix != ".md" or ".." in relative.parts:
            raise ValueError(f"{path}.stories[{position - 1}] is unsafe")
        item, index = load_story(path.parent / relative, path.parent.name, public_base_url)
        item["position"] = position
        items.append(item)
        indexes.append(index)
    payload = complete_edition(
        {
            "id": edition_id,
            "date": metadata.get("date"),
            "title": title,
            "dek": dek,
            "generated_at": metadata.get("generated_at"),
            "items": items,
        }
    )
    validate_edition(payload)
    return payload, {
        "edition_path": path,
        "edition_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "stories": indexes,
    }


def story_markdown(item: dict, provenance: dict) -> str:
    metadata = {
        "id": item["id"],
        "kind": item["kind"],
        "topic_ids": item["topic_ids"],
        "source_name": item["source_name"],
        "source_url": item["source_url"],
        "published_at": item["published_at"],
        "reading_minutes": item["reading_minutes"],
        "related_story_ids": item.get("related_story_ids", []),
        "related_event_ids": item.get("related_event_ids", []),
        "model_provider": provenance.get("provider"),
        "model_name": provenance.get("model"),
        "prompt_version": provenance.get("prompt_version") or provenance.get("prompt_versions"),
        "researched_at": provenance.get("completed_at") or provenance.get("researched_at"),
    }
    sources = "\n".join(
        f"- [{citation['title']}]({citation['url']}) | {citation['source_name']} | {citation['published_at'] or 'null'}"
        for citation in item["citations"]
    )
    body = (
        f"# {item['title']}\n\n> {item['summary']}\n\n{item['body']}\n\n"
        f"## Why this was selected\n\n{item['why_selected']}\n\n## Sources\n\n{sources}"
    )
    return render_document(metadata, body)


def edition_markdown(payload: dict, filenames: list[str]) -> str:
    metadata = {
        "id": payload["id"],
        "date": payload["date"],
        "generated_at": payload["generated_at"],
        "stories": filenames,
    }
    return render_document(metadata, f"# {payload['title']}\n\n{payload['dek']}")


def write_edition(
    payload: dict,
    root: Path,
    provenance: dict[str, dict] | None = None,
    public_base_url: str | None = None,
) -> tuple[dict, dict]:
    completed = complete_edition(deepcopy(payload))
    validate_edition(completed)
    provenance = provenance or {}
    editions = root / "editions"
    editions.mkdir(parents=True, exist_ok=True)
    staging = editions / f".{completed['date']}.{uuid.uuid4().hex}.tmp"
    staging.mkdir()
    filenames = []
    for item in completed["items"]:
        filename = f"{item['position']:02d}-{item['id']}.md"
        filenames.append(filename)
        (staging / filename).write_text(
            story_markdown(item, provenance.get(item["id"], {})),
            encoding="utf-8",
        )
    (staging / "edition.md").write_text(edition_markdown(completed, filenames), encoding="utf-8")
    load_edition(staging / "edition.md")
    destination = editions / completed["date"]
    backup = editions / f".{completed['date']}.{uuid.uuid4().hex}.backup"
    if destination.exists():
        destination.replace(backup)
    try:
        staging.replace(destination)
    except Exception:
        if backup.exists():
            backup.replace(destination)
        raise
    shutil.rmtree(backup, ignore_errors=True)
    return load_edition(destination / "edition.md", public_base_url)


def parse_preferences(path: Path) -> dict:
    metadata, body = parse_document(path)
    if metadata.get("version") != 1:
        raise ValueError(f"{path}.version must be 1")
    lines = body.splitlines()
    if not lines or lines[0] != "# Preferences":
        raise ValueError(f"{path} must begin with # Preferences")
    topics = []
    index = 1
    while index < len(lines):
        if not lines[index].strip():
            index += 1
            continue
        if not lines[index].startswith("## "):
            raise ValueError(f"invalid preference heading at {path}:{index + 1}")
        name = lines[index][3:].strip()
        index += 1
        values = {}
        while index < len(lines) and lines[index].startswith("- "):
            key, separator, value = lines[index][2:].partition(":")
            if not separator:
                raise ValueError(f"invalid preference field at {path}:{index + 1}")
            values[key.strip()] = decode_scalar(value)
            index += 1
        description = []
        while index < len(lines) and not lines[index].startswith("## "):
            if lines[index].strip():
                description.append(lines[index].strip())
            index += 1
        topics.append(
            {
                "id": values.get("id"),
                "name": name,
                "kind": values.get("kind"),
                "description": " ".join(description),
                "is_enabled": values.get("enabled"),
                "position": values.get("position"),
            }
        )
    return validate_topics({"topics": topics})


def preferences_markdown(payload: dict) -> str:
    validate_topics(payload)
    sections = []
    for topic in sorted(payload["topics"], key=lambda item: item["position"]):
        sections.append(
            f"## {topic['name']}\n"
            f"- id: {encode_scalar(topic['id'])}\n"
            f"- kind: {encode_scalar(topic['kind'])}\n"
            f"- enabled: {encode_scalar(topic['is_enabled'])}\n"
            f"- position: {encode_scalar(topic['position'])}\n\n"
            f"{topic['description']}"
        )
    return render_document({"version": 1}, "# Preferences\n\n" + "\n\n".join(sections))


def write_preferences(path: Path, payload: dict) -> None:
    write_preferences_markdown(path, preferences_markdown(payload))


def write_preferences_markdown(path: Path, markdown: object) -> dict:
    if not isinstance(markdown, str) or not markdown.strip():
        raise ValueError("preferences markdown must be a non-empty string")
    if "\x00" in markdown:
        raise ValueError("preferences markdown must not contain null bytes")
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{uuid.uuid4().hex}.tmp")
    try:
        temporary.write_text(markdown, encoding="utf-8")
        temporary.chmod(0o600)
        payload = parse_preferences(temporary)
        temporary.replace(path)
        return payload
    finally:
        temporary.unlink(missing_ok=True)


def deep_dive_markdown(story_id: str, payload: dict, provenance: dict) -> str:
    metadata = {
        "story_id": story_id,
        "status": "ready",
        "generated_at": provenance.get("completed_at") or provenance.get("researched_at"),
        "model_provider": provenance.get("provider"),
        "model_name": provenance.get("model"),
        "citations": payload["citations"],
    }
    sources = "\n".join(
        f"- [{citation['title']}]({citation['url']}) | {citation['source_name']} | {citation['published_at'] or 'null'}"
        for citation in payload["citations"]
    )
    return render_document(
        metadata,
        f"# {payload['title']}\n\n{payload['body']}\n\n## Sources\n\n{sources}",
    )


def write_deep_dive(root: Path, story_id: str, payload: dict, provenance: dict) -> Path:
    require_identifier(story_id, "deep_dive.story_id")
    destination = root / "deep-dives" / "ready" / f"{story_id}.md"
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix(".md.tmp")
    temporary.write_text(deep_dive_markdown(story_id, payload, provenance), encoding="utf-8")
    load_deep_dive(temporary)
    temporary.replace(destination)
    return destination


def load_deep_dive(path: Path) -> tuple[str, dict, dict]:
    metadata, body = parse_document(path)
    story_id = require_identifier(metadata.get("story_id"), f"{path}.story_id")
    if metadata.get("status") != "ready":
        raise ValueError(f"{path}.status must be ready")
    lines = body.splitlines()
    if not lines or not lines[0].startswith("# ") or "## Sources" not in lines:
        raise ValueError(f"{path} deep dive is incomplete")
    source_index = lines.index("## Sources")
    title = lines[0][2:].strip()
    article_body = "\n".join(lines[1:source_index]).strip()
    citations = metadata.get("citations")
    if not title or not article_body or not isinstance(citations, list) or not citations:
        raise ValueError(f"{path} deep dive is incomplete")
    validate_citations(citations, f"{path}.citations")
    return story_id, {"title": title, "body": article_body, "citations": citations}, {
        "provider": metadata.get("model_provider"),
        "model": metadata.get("model_name"),
        "completed_at": metadata.get("generated_at"),
        "source": "markdown",
    }
