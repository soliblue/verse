import hashlib
import json
import sqlite3

from db.connection import json_text, transaction, utc_now
from etl.explore import EVENT_FEEDBACK_KINDS, validate_explore


EMPTY_SIGNALS = {kind: False for kind in sorted(EVENT_FEEDBACK_KINDS)}
EMPTY_VENUE_FEEDBACK = {"more_from_here": False, "muted": False, "updated_at": None}


def publish_explore(connection: sqlite3.Connection, payload: dict, source_events: list[dict] | None = None) -> dict:
    payload = {**payload, "attended_events": payload.get("attended_events", [])}
    validate_explore(payload)
    now = utc_now()
    payload_events = payload.get("events")
    if payload_events is None:
        payload_events = payload["featured_events"]
    candidates = source_events or [*payload_events, *payload["attended_events"]]
    events = list(
        {
            item["occurrence"]["id"]: item
            for item in candidates
            if item.get("verified", True) or item.get("historical", False)
        }.values()
    )
    venue_values = {venue["id"]: venue for venue in payload["venues"]}
    venue_values.update({item["venue"]["id"]: item["venue"] for item in events})
    with transaction(connection, immediate=True):
        for venue in venue_values.values():
            connection.execute(
                "INSERT INTO venues "
                "(id, name, address, latitude, longitude, neighborhood, official_url, calendar_url, why_watched, "
                "distance_band, watch_state, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) "
                "ON CONFLICT(id) DO UPDATE SET name = excluded.name, address = excluded.address, "
                "latitude = excluded.latitude, longitude = excluded.longitude, neighborhood = excluded.neighborhood, "
                "official_url = excluded.official_url, calendar_url = excluded.calendar_url, "
                "why_watched = excluded.why_watched, distance_band = excluded.distance_band, "
                "watch_state = excluded.watch_state, updated_at = excluded.updated_at",
                (
                    venue["id"], venue["name"], venue.get("address"), venue.get("latitude"), venue.get("longitude"),
                    venue.get("neighborhood"), venue["official_url"], venue.get("calendar_url"), venue["why_watched"],
                    venue["distance_band"], venue["watch_state"], now,
                ),
            )
        for item in events:
            series_id = item.get("series_id")
            if series_id is not None:
                connection.execute(
                    "INSERT INTO event_series (id, name, updated_at) VALUES (?, ?, ?) "
                    "ON CONFLICT(id) DO UPDATE SET name = excluded.name, updated_at = excluded.updated_at",
                    (series_id, item["title"], now),
                )
            connection.execute(
                "INSERT INTO events "
                "(id, series_id, title, description, categories_json, why_selected, organizer, venue_id, official_url, "
                "source_name, checked_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) "
                "ON CONFLICT(id) DO UPDATE SET series_id = excluded.series_id, title = excluded.title, "
                "description = excluded.description, categories_json = excluded.categories_json, "
                "why_selected = excluded.why_selected, organizer = excluded.organizer, venue_id = excluded.venue_id, "
                "official_url = excluded.official_url, source_name = excluded.source_name, "
                "checked_at = excluded.checked_at, updated_at = excluded.updated_at",
                (
                    item["id"], series_id, item["title"], item["description"], json_text(item["categories"]),
                    item["why_selected"], item.get("organizer"), item["venue"]["id"], item["official_url"],
                    item["source_name"], item["checked_at"], now,
                ),
            )
            occurrence = item["occurrence"]
            connection.execute(
                "INSERT INTO event_occurrences "
                "(id, event_id, start_at, end_at, doors_at, state, novelty, price_eur, reduced_price_eur, is_free, "
                "rsvp_required, sold_out, booking_url, languages_json, accessibility_notes, age_limit, outdoor, "
                "weather_dependent, first_reported_at, last_meaningful_update_at, updated_at) "
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) "
                "ON CONFLICT(id) DO UPDATE SET event_id = excluded.event_id, start_at = excluded.start_at, "
                "end_at = excluded.end_at, doors_at = excluded.doors_at, state = excluded.state, novelty = excluded.novelty, "
                "price_eur = excluded.price_eur, reduced_price_eur = excluded.reduced_price_eur, "
                "is_free = excluded.is_free, rsvp_required = excluded.rsvp_required, sold_out = excluded.sold_out, "
                "booking_url = excluded.booking_url, languages_json = excluded.languages_json, "
                "accessibility_notes = excluded.accessibility_notes, age_limit = excluded.age_limit, outdoor = excluded.outdoor, "
                "weather_dependent = excluded.weather_dependent, first_reported_at = excluded.first_reported_at, "
                "last_meaningful_update_at = excluded.last_meaningful_update_at, updated_at = excluded.updated_at",
                (
                    occurrence["id"], occurrence["event_id"], occurrence["start_at"], occurrence.get("end_at"),
                    occurrence.get("doors_at"), occurrence["state"], occurrence["novelty"], occurrence.get("price_eur"),
                    occurrence.get("reduced_price_eur"), int(occurrence["is_free"]), int(occurrence["rsvp_required"]),
                    int(occurrence["sold_out"]), occurrence.get("booking_url"), json_text(occurrence["languages"]),
                    occurrence.get("accessibility_notes"), occurrence.get("age_limit"), int(occurrence["outdoor"]),
                    int(occurrence["weather_dependent"]), occurrence["first_reported_at"],
                    occurrence["last_meaningful_update_at"], now,
                ),
            )
            source = item["source_evidence"]
            connection.execute(
                "INSERT INTO event_sources (occurrence_id, url, source_name, checked_at, evidence) VALUES (?, ?, ?, ?, ?) "
                "ON CONFLICT(occurrence_id, url) DO UPDATE SET source_name = excluded.source_name, "
                "checked_at = excluded.checked_at, evidence = excluded.evidence",
                (occurrence["id"], source["url"], source["source_name"], source["checked_at"], source["evidence"]),
            )
            for kind in item.get("seed_feedback", []):
                exists = connection.execute(
                    "SELECT 1 FROM event_feedback_events WHERE event_id = ? AND occurrence_id = ? AND kind = ? LIMIT 1",
                    (item["id"], occurrence["id"], kind),
                ).fetchone()
                if exists is None:
                    record_event_feedback(connection, item["id"], occurrence["id"], kind, True)
        serialized = json_text(payload)
        connection.execute(
            "INSERT INTO explore_snapshots "
            "(id, generated_at, horizon_start, horizon_end, payload_json, markdown_sha256, created_at) "
            "VALUES (?, ?, ?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET generated_at = excluded.generated_at, "
            "horizon_start = excluded.horizon_start, horizon_end = excluded.horizon_end, payload_json = excluded.payload_json, "
            "markdown_sha256 = excluded.markdown_sha256, created_at = excluded.created_at",
            (
                payload["id"], payload["generated_at"], payload["horizon_start"], payload["horizon_end"], serialized,
                hashlib.sha256(serialized.encode()).hexdigest(), now,
            ),
        )
        connection.execute(
            "INSERT INTO explore_settings (key, value, updated_at) VALUES ('current_snapshot_id', ?, ?) "
            "ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at",
            (payload["id"], now),
        )
    return payload


def current_explore(connection: sqlite3.Connection) -> dict | None:
    row = connection.execute(
        "SELECT s.payload_json FROM explore_snapshots s JOIN explore_settings c "
        "ON c.key = 'current_snapshot_id' AND c.value = s.id"
    ).fetchone()
    if row is None:
        return None
    payload = json.loads(row["payload_json"])
    payload.setdefault("attended_events", [])
    return payload


def watched_venues(connection: sqlite3.Connection) -> dict:
    payload = current_explore(connection)
    return {
        "venues": []
        if payload is None
        else [venue for venue in payload["venues"] if venue["watch_state"] not in {"muted", "archived"}]
    }


def venue_feedback_state(connection: sqlite3.Connection, venue_id: str) -> dict:
    row = connection.execute(
        "SELECT more_from_here, muted, updated_at FROM venue_feedback_state WHERE venue_id = ?",
        (venue_id,),
    ).fetchone()
    if row is None:
        return EMPTY_VENUE_FEEDBACK.copy()
    return {
        "more_from_here": bool(row["more_from_here"]),
        "muted": bool(row["muted"]),
        "updated_at": row["updated_at"],
    }


def venue_record(connection: sqlite3.Connection, venue_id: str) -> dict:
    row = connection.execute(
        "SELECT id, name, address, latitude, longitude, neighborhood, official_url, calendar_url, "
        "why_watched, distance_band, watch_state FROM venues WHERE id = ?",
        (venue_id,),
    ).fetchone()
    if row is None:
        raise LookupError("venue not found")
    return {
        "id": row["id"],
        "name": row["name"],
        "address": row["address"],
        "latitude": row["latitude"],
        "longitude": row["longitude"],
        "neighborhood": row["neighborhood"],
        "official_url": row["official_url"],
        "calendar_url": row["calendar_url"],
        "why_watched": row["why_watched"],
        "distance_band": row["distance_band"],
        "watch_state": row["watch_state"],
        "next_event_id": None,
    }


def materialize_venue_state(connection: sqlite3.Connection, venue: dict) -> None:
    row = connection.execute(
        "SELECT s.id, s.payload_json FROM explore_snapshots s JOIN explore_settings c "
        "ON c.key = 'current_snapshot_id' AND c.value = s.id"
    ).fetchone()
    if row is None:
        return
    payload = json.loads(row["payload_json"])
    next_event_id = next(
        (
            value.get("next_event_id")
            for value in payload["venues"]
            if value["id"] == venue["id"]
        ),
        None,
    )
    updated = {**venue, "next_event_id": next_event_id}
    venues = [updated if value["id"] == venue["id"] else value for value in payload["venues"]]
    if not any(value["id"] == venue["id"] for value in venues) and venue["watch_state"] not in {"muted", "archived"}:
        venues.append(updated)
    payload["venues"] = (
        [value for value in venues if value["id"] != venue["id"]]
        if venue["watch_state"] in {"muted", "archived"}
        else sorted(venues, key=lambda value: (value["name"].casefold(), value["id"]))
    )
    for key in ("featured_events", "events", "attended_events"):
        if key not in payload:
            continue
        values = payload[key]
        if key == "featured_events" and venue["watch_state"] in {"muted", "archived"}:
            values = [value for value in values if value["venue"]["id"] != venue["id"]]
        for value in values:
            if value["venue"]["id"] == venue["id"]:
                value["venue"] = updated
        payload[key] = values
    validate_explore(payload)
    connection.execute(
        "UPDATE explore_snapshots SET payload_json = ? WHERE id = ?",
        (json_text(payload), row["id"]),
    )


def record_venue_feedback(connection: sqlite3.Connection, venue_id: str, kind: str, value: bool) -> dict:
    if kind not in {"more_from_here", "mute"}:
        raise ValueError("venue feedback kind is invalid")
    if not isinstance(value, bool):
        raise ValueError("venue feedback value must be a boolean")
    with transaction(connection, immediate=True):
        venue = venue_record(connection, venue_id)
        state = venue_feedback_state(connection, venue_id)
        state["more_from_here" if kind == "more_from_here" else "muted"] = value
        state["updated_at"] = utc_now()
        if state["muted"]:
            watch_state = "muted"
        elif state["more_from_here"]:
            watch_state = "favorite"
        elif venue["watch_state"] in {"muted", "favorite"}:
            watch_state = "watch"
        else:
            watch_state = venue["watch_state"]
        connection.execute(
            "INSERT INTO venue_feedback_state (venue_id, more_from_here, muted, updated_at) VALUES (?, ?, ?, ?) "
            "ON CONFLICT(venue_id) DO UPDATE SET more_from_here = excluded.more_from_here, "
            "muted = excluded.muted, updated_at = excluded.updated_at",
            (venue_id, int(state["more_from_here"]), int(state["muted"]), state["updated_at"]),
        )
        connection.execute(
            "INSERT INTO venue_feedback_events (venue_id, kind, value, created_at) VALUES (?, ?, ?, ?)",
            (venue_id, kind, int(value), state["updated_at"]),
        )
        connection.execute(
            "UPDATE venues SET watch_state = ?, updated_at = ? WHERE id = ?",
            (watch_state, state["updated_at"], venue_id),
        )
        venue = venue_record(connection, venue_id)
        materialize_venue_state(connection, venue)
    return {"feedback": state, "venue": venue}


def event_feedback_state(connection: sqlite3.Connection, event_id: str, occurrence_id: str | None) -> dict:
    row = connection.execute(
        "SELECT signals_json, updated_at FROM event_feedback_state WHERE event_id = ? AND occurrence_key = ?",
        (event_id, occurrence_id or ""),
    ).fetchone()
    if row is None:
        return {"signals": EMPTY_SIGNALS.copy(), "updated_at": None}
    return {"signals": {**EMPTY_SIGNALS, **json.loads(row["signals_json"])}, "updated_at": row["updated_at"]}


def record_event_feedback(
    connection: sqlite3.Connection,
    event_id: str,
    occurrence_id: str | None,
    kind: str,
    value: bool,
) -> dict:
    if kind not in EVENT_FEEDBACK_KINDS:
        raise ValueError("event feedback kind is invalid")
    if not isinstance(value, bool):
        raise ValueError("event feedback value must be a boolean")
    if connection.execute("SELECT 1 FROM events WHERE id = ?", (event_id,)).fetchone() is None:
        raise LookupError("event not found")
    if occurrence_id is not None and connection.execute(
        "SELECT 1 FROM event_occurrences WHERE id = ? AND event_id = ?", (occurrence_id, event_id)
    ).fetchone() is None:
        raise LookupError("event occurrence not found")
    with transaction(connection, immediate=True):
        state = event_feedback_state(connection, event_id, occurrence_id)
        state["signals"][kind] = value
        state["updated_at"] = utc_now()
        connection.execute(
            "INSERT INTO event_feedback_state (event_id, occurrence_key, occurrence_id, signals_json, updated_at) "
            "VALUES (?, ?, ?, ?, ?) ON CONFLICT(event_id, occurrence_key) DO UPDATE SET "
            "occurrence_id = excluded.occurrence_id, signals_json = excluded.signals_json, updated_at = excluded.updated_at",
            (event_id, occurrence_id or "", occurrence_id, json_text(state["signals"]), state["updated_at"]),
        )
        connection.execute(
            "INSERT INTO event_feedback_events (event_id, occurrence_id, kind, value, created_at) VALUES (?, ?, ?, ?, ?)",
            (event_id, occurrence_id, kind, int(value), state["updated_at"]),
        )
    return state


def event_ranking_profile(connection: sqlite3.Connection) -> dict:
    category_scores: dict[str, float] = {}
    venue_scores: dict[str, float] = {}
    weights = {
        "interested": 0.3,
        "going": 0.7,
        "attended": 1.0,
        "loved": 1.5,
        "not_for_me": -1.5,
        "too_far": -0.7,
        "too_expensive": -0.7,
        "sold_out": -0.2,
        "more_from_venue": 1.0,
        "more_like_this": 1.0,
    }
    rows = connection.execute(
        "SELECT e.categories_json, e.venue_id, s.signals_json FROM event_feedback_state s "
        "JOIN events e ON e.id = s.event_id"
    )
    for row in rows:
        signals = json.loads(row["signals_json"])
        score = sum(weights[kind] for kind, enabled in signals.items() if enabled)
        for category in json.loads(row["categories_json"]):
            category_scores[category] = category_scores.get(category, 0) + score
        venue_scores[row["venue_id"]] = venue_scores.get(row["venue_id"], 0) + score
    watch_states = {row["id"]: row["watch_state"] for row in connection.execute("SELECT id, watch_state FROM venues")}
    for row in connection.execute("SELECT venue_id, more_from_here, muted FROM venue_feedback_state"):
        venue_scores[row["venue_id"]] = venue_scores.get(row["venue_id"], 0) + (
            -4 if row["muted"] else 2 if row["more_from_here"] else 0
        )
    attended_occurrence_ids = sorted(
        row["occurrence_id"]
        for row in connection.execute(
            "SELECT occurrence_id, signals_json FROM event_feedback_state WHERE occurrence_id IS NOT NULL"
        )
        if json.loads(row["signals_json"]).get("attended") is True
    )
    featured_history = []
    for row in connection.execute(
        "SELECT horizon_start, horizon_end, payload_json FROM explore_snapshots ORDER BY horizon_start DESC"
    ):
        payload = json.loads(row["payload_json"])
        featured = payload.get("featured_events", [])
        featured_history.append(
            {
                "horizon_start": row["horizon_start"],
                "horizon_end": row["horizon_end"],
                "occurrence_ids": sorted({item["occurrence"]["id"] for item in featured}),
                "series_keys": sorted({item.get("series_id") or item["id"] for item in featured}),
            }
        )
    return {
        "categories": category_scores,
        "venues": venue_scores,
        "watch_states": watch_states,
        "attended_occurrence_ids": attended_occurrence_ids,
        "featured_history": featured_history,
    }
