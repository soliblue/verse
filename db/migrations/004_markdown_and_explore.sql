CREATE TABLE edition_documents (
    edition_id TEXT PRIMARY KEY REFERENCES editions(id) ON DELETE CASCADE,
    markdown_path TEXT NOT NULL UNIQUE,
    content_sha256 TEXT NOT NULL,
    indexed_at TEXT NOT NULL
);

CREATE TABLE story_documents (
    story_id TEXT PRIMARY KEY REFERENCES stories(id) ON DELETE CASCADE,
    markdown_path TEXT NOT NULL UNIQUE,
    content_sha256 TEXT NOT NULL,
    cover_path TEXT,
    cover_prompt TEXT,
    cover_model TEXT,
    cover_width INTEGER CHECK (cover_width IS NULL OR cover_width > 0),
    cover_height INTEGER CHECK (cover_height IS NULL OR cover_height > 0),
    cover_is_fallback INTEGER NOT NULL DEFAULT 0 CHECK (cover_is_fallback IN (0, 1)),
    indexed_at TEXT NOT NULL
);

CREATE TABLE story_topics (
    story_id TEXT NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
    topic_id TEXT NOT NULL,
    PRIMARY KEY (story_id, topic_id)
);

CREATE INDEX story_topics_topic ON story_topics(topic_id, story_id);

CREATE TABLE story_relations (
    source_story_id TEXT NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
    target_story_id TEXT NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
    relation TEXT NOT NULL CHECK (relation IN ('related', 'shared_topic', 'update', 'background')),
    score REAL NOT NULL CHECK (score >= 0 AND score <= 1),
    evidence TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    PRIMARY KEY (source_story_id, target_story_id, relation),
    CHECK (source_story_id <> target_story_id)
);

CREATE INDEX story_relations_target ON story_relations(target_story_id, score DESC);

CREATE TABLE event_series (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE venues (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    address TEXT,
    latitude REAL,
    longitude REAL,
    neighborhood TEXT,
    official_url TEXT NOT NULL,
    calendar_url TEXT,
    why_watched TEXT NOT NULL,
    distance_band TEXT NOT NULL CHECK (distance_band IN ('walkable', 'short_ride', 'destination', 'unknown')),
    watch_state TEXT NOT NULL CHECK (watch_state IN ('favorite', 'watch', 'muted', 'archived')),
    updated_at TEXT NOT NULL
);

CREATE TABLE events (
    id TEXT PRIMARY KEY,
    series_id TEXT REFERENCES event_series(id),
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    categories_json TEXT NOT NULL,
    why_selected TEXT NOT NULL,
    organizer TEXT,
    venue_id TEXT NOT NULL REFERENCES venues(id),
    official_url TEXT NOT NULL,
    source_name TEXT NOT NULL,
    checked_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE event_occurrences (
    id TEXT PRIMARY KEY,
    event_id TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    start_at TEXT NOT NULL,
    end_at TEXT,
    doors_at TEXT,
    state TEXT NOT NULL CHECK (state IN ('upcoming', 'happening', 'ended', 'cancelled', 'unknown')),
    novelty TEXT NOT NULL CHECK (novelty IN ('new', 'meaningful_update', 'final_chance', 'previously_reported')),
    price_eur REAL,
    reduced_price_eur REAL,
    is_free INTEGER NOT NULL CHECK (is_free IN (0, 1)),
    rsvp_required INTEGER NOT NULL CHECK (rsvp_required IN (0, 1)),
    sold_out INTEGER NOT NULL CHECK (sold_out IN (0, 1)),
    booking_url TEXT,
    languages_json TEXT NOT NULL,
    accessibility_notes TEXT,
    age_limit TEXT,
    outdoor INTEGER NOT NULL CHECK (outdoor IN (0, 1)),
    weather_dependent INTEGER NOT NULL CHECK (weather_dependent IN (0, 1)),
    first_reported_at TEXT NOT NULL,
    last_meaningful_update_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE INDEX event_occurrences_start ON event_occurrences(start_at, state);
CREATE INDEX event_occurrences_event ON event_occurrences(event_id, start_at);

CREATE TABLE event_sources (
    occurrence_id TEXT NOT NULL REFERENCES event_occurrences(id) ON DELETE CASCADE,
    url TEXT NOT NULL,
    source_name TEXT NOT NULL,
    checked_at TEXT NOT NULL,
    evidence TEXT NOT NULL,
    PRIMARY KEY (occurrence_id, url)
);

CREATE TABLE story_events (
    story_id TEXT NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
    occurrence_id TEXT NOT NULL,
    PRIMARY KEY (story_id, occurrence_id)
);

CREATE TABLE event_feedback_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_id TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    occurrence_id TEXT REFERENCES event_occurrences(id) ON DELETE CASCADE,
    kind TEXT NOT NULL CHECK (kind IN ('interested', 'going', 'attended', 'loved', 'not_for_me', 'too_far', 'too_expensive', 'sold_out', 'more_from_venue', 'more_like_this')),
    value INTEGER NOT NULL CHECK (value IN (0, 1)),
    created_at TEXT NOT NULL
);

CREATE INDEX event_feedback_events_event ON event_feedback_events(event_id, created_at DESC);

CREATE TABLE event_feedback_state (
    event_id TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    occurrence_key TEXT NOT NULL,
    occurrence_id TEXT REFERENCES event_occurrences(id) ON DELETE CASCADE,
    signals_json TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    PRIMARY KEY (event_id, occurrence_key)
);

CREATE TABLE explore_snapshots (
    id TEXT PRIMARY KEY,
    generated_at TEXT NOT NULL,
    horizon_start TEXT NOT NULL,
    horizon_end TEXT NOT NULL,
    payload_json TEXT NOT NULL,
    markdown_sha256 TEXT NOT NULL,
    created_at TEXT NOT NULL
);

CREATE INDEX explore_snapshots_generated ON explore_snapshots(generated_at DESC);

CREATE TABLE explore_settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
