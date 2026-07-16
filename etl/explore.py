import json
import math
import os
from datetime import UTC, date, datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

from etl.content import decode_scalar, parse_document
from etl.validation import require_text, require_timestamp, require_url


BERLIN = ZoneInfo("Europe/Berlin")
EVENT_STATES = {"upcoming", "happening", "ended", "cancelled", "unknown"}
NOVELTY_STATES = {"new", "meaningful_update", "final_chance", "previously_reported"}
DISTANCE_BANDS = {"walkable", "short_ride", "destination", "unknown"}
WATCH_STATES = {"favorite", "watch", "muted", "archived"}
EVENT_FEEDBACK_KINDS = {
    "interested",
    "going",
    "attended",
    "loved",
    "not_for_me",
    "too_far",
    "too_expensive",
    "sold_out",
    "more_from_venue",
    "more_like_this",
}
ATTENDED_HISTORY_LIMIT = 12


def private_anchor() -> tuple[float, float] | None:
    value = os.environ.get("VERSE_PROXIMITY_ANCHOR")
    if not value:
        return None
    latitude_text, separator, longitude_text = value.partition(",")
    if not separator:
        raise ValueError("VERSE_PROXIMITY_ANCHOR must be latitude,longitude")
    latitude = float(latitude_text)
    longitude = float(longitude_text)
    if not -90 <= latitude <= 90 or not -180 <= longitude <= 180:
        raise ValueError("VERSE_PROXIMITY_ANCHOR coordinates are invalid")
    return latitude, longitude


def distance_band(venue: dict, anchor: tuple[float, float] | None) -> str:
    if anchor is None or venue.get("latitude") is None or venue.get("longitude") is None:
        return "unknown"
    latitude, longitude = map(math.radians, anchor)
    venue_latitude = math.radians(venue["latitude"])
    venue_longitude = math.radians(venue["longitude"])
    latitude_delta = venue_latitude - latitude
    longitude_delta = venue_longitude - longitude
    value = math.sin(latitude_delta / 2) ** 2 + math.cos(latitude) * math.cos(venue_latitude) * math.sin(
        longitude_delta / 2
    ) ** 2
    value = min(1, max(0, value))
    kilometers = 6371 * 2 * math.atan2(math.sqrt(value), math.sqrt(1 - value))
    if kilometers <= 2.5:
        return "walkable"
    if kilometers <= 7:
        return "short_ride"
    return "destination"


def parse_places(path: Path) -> list[dict]:
    metadata, body = parse_document(path)
    if metadata.get("version") != 1:
        raise ValueError(f"{path}.version must be 1")
    lines = body.splitlines()
    if not lines or lines[0] != "# Places":
        raise ValueError(f"{path} must begin with # Places")
    venues = []
    index = 1
    while index < len(lines):
        if not lines[index].strip():
            index += 1
            continue
        if not lines[index].startswith("## "):
            raise ValueError(f"invalid place heading at {path}:{index + 1}")
        name = lines[index][3:].strip()
        index += 1
        fields = {}
        while index < len(lines) and lines[index].startswith("- "):
            key, separator, value = lines[index][2:].partition(":")
            if not separator:
                raise ValueError(f"invalid place field at {path}:{index + 1}")
            fields[key.strip()] = decode_scalar(value)
            index += 1
        reason = []
        while index < len(lines) and not lines[index].startswith("## "):
            if lines[index].strip():
                reason.append(lines[index].strip())
            index += 1
        venues.append(
            {
                "id": fields.get("id"),
                "name": name,
                "address": fields.get("address"),
                "latitude": fields.get("latitude"),
                "longitude": fields.get("longitude"),
                "neighborhood": fields.get("neighborhood"),
                "official_url": fields.get("official_url"),
                "calendar_url": fields.get("calendar_url"),
                "why_watched": " ".join(reason),
                "distance_band": fields.get("distance_band", "unknown"),
                "watch_state": fields.get("watch_state", "watch"),
                "next_event_id": None,
            }
        )
    validate_venues(venues)
    return venues


def event_sections(body: str, path: Path) -> tuple[str, str, str]:
    lines = body.splitlines()
    if not lines or not lines[0].startswith("# "):
        raise ValueError(f"{path} must begin with an event title")
    marker = "## Why this was selected"
    if marker not in lines:
        raise ValueError(f"{path} must contain a selection section")
    marker_index = lines.index(marker)
    title = lines[0][2:].strip()
    description = "\n".join(lines[1:marker_index]).strip()
    why_selected = "\n".join(lines[marker_index + 1 :]).strip()
    if not title or not description or not why_selected:
        raise ValueError(f"{path} event content is incomplete")
    return title, description, why_selected


def parse_event(path: Path, venues: dict[str, dict]) -> dict:
    metadata, body = parse_document(path)
    title, description, why_selected = event_sections(body, path)
    venue_id = metadata.get("venue_id")
    if venue_id not in venues:
        raise ValueError(f"{path}.venue_id is unknown")
    occurrence = {
        "id": metadata.get("occurrence_id"),
        "event_id": metadata.get("id"),
        "title": title,
        "venue_id": venue_id,
        "start_at": metadata.get("start_at"),
        "end_at": metadata.get("end_at"),
        "doors_at": metadata.get("doors_at"),
        "state": metadata.get("state", "upcoming"),
        "novelty": metadata.get("novelty", "new"),
        "price_eur": metadata.get("price_eur"),
        "reduced_price_eur": metadata.get("reduced_price_eur"),
        "is_free": metadata.get("is_free", False),
        "rsvp_required": metadata.get("rsvp_required", False),
        "sold_out": metadata.get("sold_out", False),
        "booking_url": metadata.get("booking_url"),
        "languages": metadata.get("languages", []),
        "accessibility_notes": metadata.get("accessibility_notes"),
        "age_limit": metadata.get("age_limit"),
        "outdoor": metadata.get("outdoor", False),
        "weather_dependent": metadata.get("weather_dependent", False),
        "first_reported_at": metadata.get("first_reported_at", metadata.get("checked_at")),
        "last_meaningful_update_at": metadata.get("last_meaningful_update_at", metadata.get("checked_at")),
    }
    item = {
        "id": metadata.get("id"),
        "series_id": metadata.get("series_id"),
        "title": title,
        "description": description,
        "categories": metadata.get("categories", []),
        "why_selected": why_selected,
        "organizer": metadata.get("organizer"),
        "occurrence": occurrence,
        "venue": venues[venue_id].copy(),
        "booking_url": metadata.get("booking_url"),
        "official_url": metadata.get("official_url"),
        "source_name": metadata.get("source_name"),
        "checked_at": metadata.get("checked_at"),
        "source_evidence": {
            "url": metadata.get("official_url"),
            "source_name": metadata.get("source_name"),
            "checked_at": metadata.get("checked_at"),
            "evidence": metadata.get("evidence"),
        },
        "rank_score": metadata.get("rank_score", 0),
        "verified": metadata.get("verified", False),
        "historical": metadata.get("historical", False),
        "seed_feedback": metadata.get("feedback", []),
    }
    validate_event(item, f"event {path.name}")
    return item


def validate_venues(venues: object) -> list[dict]:
    if not isinstance(venues, list):
        raise ValueError("venues must be an array")
    ids = []
    for index, venue in enumerate(venues):
        path = f"venues[{index}]"
        if not isinstance(venue, dict):
            raise ValueError(f"{path} must be an object")
        ids.append(require_text(venue.get("id"), f"{path}.id"))
        require_text(venue.get("name"), f"{path}.name")
        require_url(venue.get("official_url"), f"{path}.official_url")
        require_url(venue.get("calendar_url"), f"{path}.calendar_url", nullable=True)
        require_text(venue.get("why_watched"), f"{path}.why_watched")
        if venue.get("distance_band") not in DISTANCE_BANDS:
            raise ValueError(f"{path}.distance_band is invalid")
        if venue.get("watch_state") not in WATCH_STATES:
            raise ValueError(f"{path}.watch_state is invalid")
        latitude = venue.get("latitude")
        longitude = venue.get("longitude")
        if (latitude is None) != (longitude is None):
            raise ValueError(f"{path} coordinates must be both present or both absent")
        if latitude is not None and (not isinstance(latitude, (int, float)) or not -90 <= latitude <= 90):
            raise ValueError(f"{path}.latitude is invalid")
        if longitude is not None and (not isinstance(longitude, (int, float)) or not -180 <= longitude <= 180):
            raise ValueError(f"{path}.longitude is invalid")
    if len(ids) != len(set(ids)):
        raise ValueError("venue ids must be unique")
    return venues


def validate_occurrence(value: object, path: str) -> dict:
    if not isinstance(value, dict):
        raise ValueError(f"{path} must be an object")
    for key in ("id", "event_id", "title", "venue_id"):
        require_text(value.get(key), f"{path}.{key}")
    require_timestamp(value.get("start_at"), f"{path}.start_at")
    require_timestamp(value.get("end_at"), f"{path}.end_at", nullable=True)
    require_timestamp(value.get("doors_at"), f"{path}.doors_at", nullable=True)
    if value.get("state") not in EVENT_STATES:
        raise ValueError(f"{path}.state is invalid")
    if value.get("novelty") not in NOVELTY_STATES:
        raise ValueError(f"{path}.novelty is invalid")
    for key in ("is_free", "rsvp_required", "sold_out", "outdoor", "weather_dependent"):
        if not isinstance(value.get(key), bool):
            raise ValueError(f"{path}.{key} must be a boolean")
    for key in ("price_eur", "reduced_price_eur"):
        if value.get(key) is not None and (not isinstance(value[key], (int, float)) or value[key] < 0):
            raise ValueError(f"{path}.{key} must be a non-negative number")
    require_url(value.get("booking_url"), f"{path}.booking_url", nullable=True)
    if not isinstance(value.get("languages"), list) or any(not isinstance(item, str) for item in value["languages"]):
        raise ValueError(f"{path}.languages must be a string array")
    require_timestamp(value.get("first_reported_at"), f"{path}.first_reported_at")
    require_timestamp(value.get("last_meaningful_update_at"), f"{path}.last_meaningful_update_at")
    return value


def validate_event(value: object, path: str) -> dict:
    if not isinstance(value, dict):
        raise ValueError(f"{path} must be an object")
    for key in ("id", "title", "description", "why_selected", "source_name"):
        require_text(value.get(key), f"{path}.{key}")
    if value.get("series_id") is not None:
        require_text(value.get("series_id"), f"{path}.series_id")
    if not isinstance(value.get("categories"), list) or not value["categories"]:
        raise ValueError(f"{path}.categories must be a non-empty array")
    require_url(value.get("official_url"), f"{path}.official_url")
    require_url(value.get("booking_url"), f"{path}.booking_url", nullable=True)
    require_timestamp(value.get("checked_at"), f"{path}.checked_at")
    if "verified" in value and not isinstance(value["verified"], bool):
        raise ValueError(f"{path}.verified must be a boolean")
    if "historical" in value and not isinstance(value["historical"], bool):
        raise ValueError(f"{path}.historical must be a boolean")
    feedback = value.get("seed_feedback", [])
    if not isinstance(feedback, list) or any(kind not in EVENT_FEEDBACK_KINDS for kind in feedback):
        raise ValueError(f"{path}.seed_feedback is invalid")
    validate_occurrence(value.get("occurrence"), f"{path}.occurrence")
    validate_venues([value.get("venue")])
    source = value.get("source_evidence")
    if not isinstance(source, dict):
        raise ValueError(f"{path}.source_evidence must be an object")
    require_url(source.get("url"), f"{path}.source_evidence.url")
    require_text(source.get("evidence"), f"{path}.source_evidence.evidence")
    return value


def validate_explore(payload: object) -> dict:
    if not isinstance(payload, dict):
        raise ValueError("explore payload must be an object")
    require_text(payload.get("id"), "explore.id")
    require_timestamp(payload.get("generated_at"), "explore.generated_at")
    if payload.get("timezone") != "Europe/Berlin":
        raise ValueError("explore.timezone must be Europe/Berlin")
    date.fromisoformat(require_text(payload.get("horizon_start"), "explore.horizon_start"))
    date.fromisoformat(require_text(payload.get("horizon_end"), "explore.horizon_end"))
    featured = payload.get("featured_events")
    if not isinstance(featured, list) or len(featured) > 12:
        raise ValueError("explore.featured_events must contain at most 12 events")
    for index, item in enumerate(featured):
        validate_event(item, f"explore.featured_events[{index}]")
        if item["occurrence"]["state"] in {"ended", "cancelled", "unknown"}:
            raise ValueError("ended, cancelled, or unknown events cannot be featured")
    attended = payload.get("attended_events", [])
    if not isinstance(attended, list) or len(attended) > ATTENDED_HISTORY_LIMIT:
        raise ValueError(f"explore.attended_events must contain at most {ATTENDED_HISTORY_LIMIT} events")
    for index, item in enumerate(attended):
        validate_event(item, f"explore.attended_events[{index}]")
        if item["occurrence"]["state"] != "ended":
            raise ValueError("attended history must contain only ended events")
    attended_occurrence_ids = [item["occurrence"]["id"] for item in attended]
    if len(attended_occurrence_ids) != len(set(attended_occurrence_ids)):
        raise ValueError("attended history occurrences must be unique")
    events = payload.get("events")
    if events is not None:
        if not isinstance(events, list):
            raise ValueError("explore.events must be an array")
        for index, item in enumerate(events):
            validate_event(item, f"explore.events[{index}]")
    validate_venues(payload.get("venues"))
    calendar = payload.get("calendar")
    if not isinstance(calendar, list):
        raise ValueError("explore.calendar must be an array")
    for index, occurrence in enumerate(calendar):
        validate_occurrence(occurrence, f"explore.calendar[{index}]")
    occurrence_ids = [item["id"] for item in calendar]
    if len(occurrence_ids) != len(set(occurrence_ids)):
        raise ValueError("explore calendar occurrences must be unique")
    if events is not None:
        event_occurrence_ids = [item["occurrence"]["id"] for item in events]
        if len(event_occurrence_ids) != len(set(event_occurrence_ids)) or set(event_occurrence_ids) != set(occurrence_ids):
            raise ValueError("explore.events must contain each calendar occurrence exactly once")
    return payload


def current_state(occurrence: dict, now: datetime) -> str:
    if occurrence["state"] in {"cancelled", "unknown"}:
        return occurrence["state"]
    start = datetime.fromisoformat(occurrence["start_at"])
    end = datetime.fromisoformat(occurrence["end_at"]) if occurrence["end_at"] else start + timedelta(hours=4)
    if now >= end:
        return "ended"
    return "happening" if start <= now else "upcoming"


def event_sort_key(item: dict) -> tuple:
    occurrence = item["occurrence"]
    distance = {"walkable": 0, "short_ride": 1, "destination": 2, "unknown": 3}[item["venue"]["distance_band"]]
    return (
        occurrence["sold_out"],
        -float(item.get("rank_score", 0)),
        distance,
        not occurrence["is_free"],
        occurrence["start_at"],
        item["id"],
    )


def transport_event(item: dict) -> dict:
    return {
        key: value
        for key, value in item.items()
        if key not in {"rank_score", "verified", "historical", "seed_feedback"}
    }


def build_explore(
    root: Path,
    now: datetime | None = None,
    horizon_days: int = 7,
    ranking_profile: dict | None = None,
) -> tuple[dict, list[dict]]:
    now = (now or datetime.now(UTC)).astimezone(BERLIN)
    horizon_start = now.date()
    horizon_end = horizon_start + timedelta(days=horizon_days - 1)
    venue_values = parse_places(root / "places.md")
    anchor = private_anchor()
    for venue in venue_values:
        venue["distance_band"] = distance_band(venue, anchor)
    ranking_profile = ranking_profile or {"categories": {}, "venues": {}, "watch_states": {}}
    for venue in venue_values:
        venue["watch_state"] = ranking_profile.get("watch_states", {}).get(venue["id"], venue["watch_state"])
    venue_map = {venue["id"]: venue for venue in venue_values}
    items = [parse_event(path, venue_map) for path in sorted((root / "events" / "upcoming").glob("*.md"))]
    archived = [parse_event(path, venue_map) for path in sorted((root / "events" / "archive").glob("*.md"))]
    for item in items:
        item["rank_score"] += sum(ranking_profile.get("categories", {}).get(value, 0) for value in item["categories"])
        item["rank_score"] += ranking_profile.get("venues", {}).get(item["venue"]["id"], 0)
    previous_occurrences = set()
    previous_series = set()
    for snapshot in ranking_profile.get("featured_history", []):
        snapshot_start = date.fromisoformat(snapshot["horizon_start"])
        snapshot_end = date.fromisoformat(snapshot["horizon_end"])
        if snapshot_start < horizon_start <= snapshot_end:
            previous_occurrences.update(snapshot.get("occurrence_ids", []))
            previous_series.update(snapshot.get("series_keys", []))
    for item in items + archived:
        item["occurrence"]["state"] = current_state(item["occurrence"], now)
    active = []
    calendar = []
    calendar_events = []
    for item in items:
        occurrence = item["occurrence"]
        start_date = datetime.fromisoformat(occurrence["start_at"]).astimezone(BERLIN).date()
        if not item["verified"] or not horizon_start <= start_date <= horizon_end:
            continue
        calendar.append(occurrence.copy())
        calendar_events.append(transport_event(item))
        if occurrence["state"] not in {"ended", "cancelled", "unknown"} and item["venue"]["watch_state"] not in {"muted", "archived"}:
            active.append(item)
    active.sort(key=event_sort_key)
    featured = []
    series = set()
    for item in active:
        series_key = item["series_id"] or item["id"]
        if series_key in series:
            continue
        occurrence = item["occurrence"]
        if occurrence["novelty"] not in {"meaningful_update", "final_chance"} and (
            occurrence["id"] in previous_occurrences or series_key in previous_series
        ):
            continue
        series.add(series_key)
        featured.append(transport_event(item))
        if len(featured) == 12:
            break
    attended_occurrence_ids = set(ranking_profile.get("attended_occurrence_ids", []))
    attended_by_occurrence = {
        item["occurrence"]["id"]: transport_event(item)
        for item in items + archived
        if item["occurrence"]["id"] in attended_occurrence_ids and item["occurrence"]["state"] == "ended"
    }
    attended = sorted(
        attended_by_occurrence.values(),
        key=lambda item: (datetime.fromisoformat(item["occurrence"]["start_at"]), item["occurrence"]["id"]),
        reverse=True,
    )[:ATTENDED_HISTORY_LIMIT]
    for venue in venue_values:
        next_event = next(
            (item["occurrence"]["id"] for item in active if item["venue"]["id"] == venue["id"]),
            None,
        )
        venue["next_event_id"] = next_event
    payload = {
        "id": f"explore-{horizon_start.isoformat()}",
        "generated_at": now.astimezone(UTC).isoformat(timespec="seconds").replace("+00:00", "Z"),
        "timezone": "Europe/Berlin",
        "horizon_start": horizon_start.isoformat(),
        "horizon_end": horizon_end.isoformat(),
        "featured_events": featured,
        "attended_events": attended,
        "events": sorted(calendar_events, key=lambda item: (item["occurrence"]["start_at"], item["occurrence"]["id"])),
        "venues": [venue for venue in venue_values if venue["watch_state"] not in {"muted", "archived"}],
        "calendar": sorted(calendar, key=lambda item: (item["start_at"], item["id"])),
    }
    return validate_explore(payload), items + archived


def materialize_explore(
    root: Path,
    now: datetime | None = None,
    horizon_days: int = 7,
    ranking_profile: dict | None = None,
) -> dict:
    return build_explore(root, now, horizon_days, ranking_profile)[0]


def write_explore(root: Path, payload: dict) -> Path:
    validate_explore(payload)
    destination = root / "explore" / "current.json"
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(destination)
    return destination
