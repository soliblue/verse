from copy import deepcopy
import json
from datetime import date, datetime
from urllib.parse import urlparse


TOPIC_KINDS = {"interest", "lab", "artist", "source", "venue", "exclusion"}
ITEM_KINDS = {"paper", "event", "technique"}
PREFERENCE_KINDS = {"more_like_this", "less_like_this", "too_basic"}
DEEP_DIVE_STATUSES = {"not_requested", "queued", "ready", "failed"}


def require_text(value: object, path: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{path} must be a non-empty string")
    return value


def require_timestamp(value: object, path: str, nullable: bool = False) -> None:
    if nullable and value is None:
        return
    require_text(value, path)
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        raise ValueError(f"{path} must include a timezone")


def require_url(value: object, path: str, nullable: bool = False) -> None:
    if nullable and value is None:
        return
    parsed = urlparse(require_text(value, path))
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise ValueError(f"{path} must be an http or https URL")


def validate_citations(value: object, path: str, allow_empty: bool = False) -> None:
    if not isinstance(value, list) or (not value and not allow_empty):
        raise ValueError(f"{path} must be a non-empty array")
    for index, citation in enumerate(value):
        if not isinstance(citation, dict):
            raise ValueError(f"{path}[{index}] must be an object")
        require_text(citation.get("title"), f"{path}[{index}].title")
        require_url(citation.get("url"), f"{path}[{index}].url")
        require_text(citation.get("source_name"), f"{path}[{index}].source_name")
        require_timestamp(citation.get("published_at"), f"{path}[{index}].published_at", nullable=True)


def validate_feedback(value: object, path: str) -> None:
    if not isinstance(value, dict):
        raise ValueError(f"{path} must be an object")
    if not isinstance(value.get("saved"), bool) or not isinstance(value.get("seen"), bool):
        raise ValueError(f"{path}.saved and {path}.seen must be booleans")
    if value.get("preference") not in PREFERENCE_KINDS | {None}:
        raise ValueError(f"{path}.preference is invalid")
    require_timestamp(value.get("updated_at"), f"{path}.updated_at", nullable=True)


def validate_deep_dive(value: object, path: str) -> None:
    if not isinstance(value, dict):
        raise ValueError(f"{path} must be an object")
    if value.get("status") not in DEEP_DIVE_STATUSES:
        raise ValueError(f"{path}.status is invalid")
    require_timestamp(value.get("requested_at"), f"{path}.requested_at", nullable=True)
    if value.get("title") is not None:
        require_text(value.get("title"), f"{path}.title")
    if value.get("body") is not None:
        require_text(value.get("body"), f"{path}.body")
    validate_citations(value.get("citations"), f"{path}.citations", allow_empty=True)
    if value.get("status") == "ready" and (value.get("title") is None or value.get("body") is None or not value.get("citations")):
        raise ValueError(f"{path} ready content is incomplete")


def complete_edition(payload: dict) -> dict:
    completed = deepcopy(payload)
    for item in completed.get("items", []):
        item.setdefault("image_url", None)
        item.setdefault("feedback", {"saved": False, "seen": False, "preference": None, "updated_at": None})
        item.setdefault(
            "deep_dive",
            {"status": "not_requested", "requested_at": None, "title": None, "body": None, "citations": []},
        )
    return completed


def validate_edition(payload: object, minimum_items: int = 8, maximum_items: int = 12) -> dict:
    if not isinstance(payload, dict):
        raise ValueError("edition must be an object")
    require_text(payload.get("id"), "edition.id")
    date.fromisoformat(require_text(payload.get("date"), "edition.date"))
    require_text(payload.get("title"), "edition.title")
    require_text(payload.get("dek"), "edition.dek")
    require_timestamp(payload.get("generated_at"), "edition.generated_at")
    items = payload.get("items")
    if not isinstance(items, list) or not minimum_items <= len(items) <= maximum_items:
        raise ValueError(f"edition.items must contain between {minimum_items} and {maximum_items} items")
    ids = []
    positions = []
    for index, item in enumerate(items):
        path = f"edition.items[{index}]"
        if not isinstance(item, dict):
            raise ValueError(f"{path} must be an object")
        ids.append(require_text(item.get("id"), f"{path}.id"))
        if not isinstance(item.get("position"), int) or isinstance(item.get("position"), bool):
            raise ValueError(f"{path}.position must be an integer")
        positions.append(item["position"])
        if item.get("kind") not in ITEM_KINDS:
            raise ValueError(f"{path}.kind is invalid")
        topic_ids = item.get("topic_ids")
        if not isinstance(topic_ids, list) or not topic_ids or any(not isinstance(topic, str) or not topic for topic in topic_ids):
            raise ValueError(f"{path}.topic_ids must be a non-empty string array")
        if len(topic_ids) != len(set(topic_ids)):
            raise ValueError(f"{path}.topic_ids must be unique")
        for field in ("related_story_ids", "related_event_ids"):
            values = item.get(field, [])
            if not isinstance(values, list) or any(not isinstance(value, str) or not value for value in values):
                raise ValueError(f"{path}.{field} must be a string array")
            if len(values) != len(set(values)):
                raise ValueError(f"{path}.{field} must be unique")
        if item["id"] in item.get("related_story_ids", []):
            raise ValueError(f"{path}.related_story_ids cannot contain itself")
        for field in ("title", "summary", "body", "why_selected", "source_name"):
            require_text(item.get(field), f"{path}.{field}")
        require_url(item.get("source_url"), f"{path}.source_url")
        require_timestamp(item.get("published_at"), f"{path}.published_at")
        if not isinstance(item.get("reading_minutes"), int) or isinstance(item.get("reading_minutes"), bool) or item["reading_minutes"] < 1:
            raise ValueError(f"{path}.reading_minutes must be a positive integer")
        require_url(item.get("image_url"), f"{path}.image_url", nullable=True)
        validate_citations(item.get("citations"), f"{path}.citations")
        validate_feedback(item.get("feedback"), f"{path}.feedback")
        validate_deep_dive(item.get("deep_dive"), f"{path}.deep_dive")
        allowed_citations = {json.dumps(citation, sort_keys=True, separators=(",", ":")) for citation in item["citations"]}
        if any(
            json.dumps(citation, sort_keys=True, separators=(",", ":")) not in allowed_citations
            for citation in item["deep_dive"]["citations"]
        ):
            raise ValueError(f"{path}.deep_dive citations must come from item citations")
    if len(ids) != len(set(ids)):
        raise ValueError("edition item ids must be unique")
    if positions != list(range(1, len(items) + 1)):
        raise ValueError("edition item positions must be ordered and contiguous from 1")
    return payload


def validate_topics(payload: object) -> dict:
    if not isinstance(payload, dict) or not isinstance(payload.get("topics"), list):
        raise ValueError("topics must be an object containing a topics array")
    ids = []
    positions = []
    for index, topic in enumerate(payload["topics"]):
        path = f"topics[{index}]"
        if not isinstance(topic, dict):
            raise ValueError(f"{path} must be an object")
        ids.append(require_text(topic.get("id"), f"{path}.id"))
        require_text(topic.get("name"), f"{path}.name")
        if topic.get("kind") not in TOPIC_KINDS:
            raise ValueError(f"{path}.kind is invalid")
        require_text(topic.get("description"), f"{path}.description")
        if not isinstance(topic.get("is_enabled"), bool):
            raise ValueError(f"{path}.is_enabled must be a boolean")
        if not isinstance(topic.get("position"), int) or isinstance(topic.get("position"), bool) or topic["position"] < 0:
            raise ValueError(f"{path}.position must be a non-negative integer")
        positions.append(topic["position"])
    if len(ids) != len(set(ids)):
        raise ValueError("topic ids must be unique")
    if len(positions) != len(set(positions)):
        raise ValueError("topic positions must be unique")
    return payload
