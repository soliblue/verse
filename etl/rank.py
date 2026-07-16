import json
import math
import re
import sqlite3
from datetime import date, datetime

from db.explore import event_ranking_profile


EXCLUSION_NOISE_WORDS = {"and", "content", "exclude", "only"}


def searchable_words(value: str) -> set[str]:
    return {word for word in re.findall(r"[a-z0-9]+", value.lower()) if len(word) > 2}


def exclusion_words(topics) -> set[str]:
    return set().union(
        *(
            searchable_words(f"{topic['id']} {topic['name']}") - EXCLUSION_NOISE_WORDS
            for topic in topics
            if topic["kind"] == "exclusion"
        )
    )


def feedback_signals(connection: sqlite3.Connection) -> list[tuple[set[str], str | None, bool]]:
    story_topics: dict[str, set[str]] = {}
    for row in connection.execute(
        "SELECT payload_json FROM editions ORDER BY edition_date DESC, generated_at DESC"
    ):
        for item in json.loads(row["payload_json"])["items"]:
            story_topics.setdefault(item["id"], set(item["topic_ids"]))
    return [
        (story_topics.get(row["story_id"], set()), row["preference"], bool(row["saved"]))
        for row in connection.execute(
            "SELECT story_id, preference, saved FROM feedback_state "
            "WHERE preference IS NOT NULL OR saved = 1"
        )
    ]


def rank_stage(connection: sqlite3.Connection, run_id: str, selection_limit: int = 10) -> int:
    if not 8 <= selection_limit <= 12:
        raise ValueError("selection limit must be between 8 and 12")
    topics = connection.execute(
        "SELECT id, name, kind, description FROM topics WHERE is_enabled = 1 ORDER BY position"
    ).fetchall()
    topic_terms = {
        topic["id"]: searchable_words(f"{topic['id']} {topic['name']} {topic['description']}") for topic in topics
    }
    exclusions = exclusion_words(topics)
    candidates = connection.execute(
        "SELECT c.normalized_item_id, c.duplicate_of, n.title, n.content, n.source_name, n.canonical_url, n.published_at, n.topic_ids_json, s.raw_json FROM run_candidates c JOIN normalized_items n ON n.id = c.normalized_item_id JOIN source_items s ON s.id = n.source_item_id WHERE c.run_id = ? ORDER BY n.published_at DESC, n.id",
        (run_id,),
    ).fetchall()
    run_date = date.fromisoformat(connection.execute("SELECT edition_date FROM etl_runs WHERE id = ?", (run_id,)).fetchone()[0])
    signals = feedback_signals(connection)
    event_profile = event_ranking_profile(connection)
    scored = []
    for row in candidates:
        raw = json.loads(row["raw_json"])
        source_quality = float(raw.get("source", {}).get("quality", 0.6))
        words = searchable_words(f"{row['title']} {row['content']} {row['source_name']}")
        declared_topics = set(json.loads(row["topic_ids_json"]))
        matches = [topic_id for topic_id, terms in topic_terms.items() if topic_id in declared_topics or len(words & terms) >= 2]
        interest = min(3.0, len(matches) * 0.55)
        is_excluded = bool(exclusions & words)
        seen = connection.execute(
            "SELECT 1 FROM stories s JOIN edition_items i ON i.story_id = s.id "
            "JOIN editions e ON e.id = i.edition_id "
            "WHERE s.source_url = ? AND e.edition_date < ? LIMIT 1",
            (row["canonical_url"], run_date.isoformat()),
        ).fetchone()
        age_days = max(0, (run_date - datetime.fromisoformat(row["published_at"].replace("Z", "+00:00")).date()).days)
        freshness = max(-0.75, 1.25 - age_days / 20)
        novelty = (-2.0 if seen else 0.75) + freshness
        feedback = 0.0
        for signal_topics, preference, saved in signals:
            overlap = len(declared_topics & signal_topics)
            if overlap:
                weight = 2 * overlap / max(1, len(declared_topics) + len(signal_topics))
                feedback += weight * {
                    "more_like_this": 0.4,
                    "less_like_this": -0.7,
                    "too_basic": -0.35,
                    None: 0.0,
                }[preference]
                feedback += weight * 0.15 if saved else 0.0
        event_feedback = 0.0
        for category, score in event_profile["categories"].items():
            terms = searchable_words(category.replace("-", " "))
            if terms and terms <= words:
                event_feedback += score * 0.08
        for venue, score in event_profile["venues"].items():
            terms = searchable_words(venue.replace("-", " "))
            if terms and terms <= words:
                event_feedback += score * 0.08
        feedback += max(-0.75, min(0.75, event_feedback))
        feedback = max(-2.0, min(2.0, feedback))
        total = source_quality * 2.0 + interest + novelty + feedback
        if row["duplicate_of"] is not None or is_excluded:
            total = -math.inf
        rationale = (
            f"source {source_quality:.2f}, interests {interest:.2f}, novelty {novelty:.2f}, "
            f"feedback {feedback:.2f}, excluded {str(is_excluded).lower()}"
        )
        scored.append(
            (
                total,
                row["normalized_item_id"],
                row["source_name"],
                source_quality,
                interest,
                novelty,
                feedback,
                rationale,
                "berlin-events" in declared_topics,
            )
        )
    ranked = sorted(scored, key=lambda item: (-item[0], item[1]))
    selected_ids = set()
    source_counts: dict[str, int] = {}
    event_count = 0
    for item in ranked:
        if (
            math.isfinite(item[0])
            and source_counts.get(item[2], 0) < 4
            and len(selected_ids) < selection_limit
            and (not item[8] or event_count < 2)
        ):
            selected_ids.add(item[1])
            source_counts[item[2]] = source_counts.get(item[2], 0) + 1
            event_count += int(item[8])
    for item in ranked:
        if math.isfinite(item[0]) and len(selected_ids) < selection_limit and (not item[8] or event_count < 2):
            selected_ids.add(item[1])
            event_count += int(item[8])
    with connection:
        for total, identifier, _, source_quality, interest, novelty, feedback, rationale, _ in scored:
            connection.execute(
                "UPDATE run_candidates SET source_quality = ?, interest_score = ?, novelty_score = ?, feedback_score = ?, total_score = ?, selected = ?, rationale = ? WHERE run_id = ? AND normalized_item_id = ?",
                (
                    source_quality,
                    interest,
                    novelty,
                    feedback,
                    total if math.isfinite(total) else -9999.0,
                    int(identifier in selected_ids),
                    rationale,
                    run_id,
                    identifier,
                ),
            )
    return len(selected_ids)
