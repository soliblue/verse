CREATE TABLE venue_feedback_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    venue_id TEXT NOT NULL REFERENCES venues(id) ON DELETE CASCADE,
    kind TEXT NOT NULL CHECK (kind IN ('more_from_here', 'mute')),
    value INTEGER NOT NULL CHECK (value IN (0, 1)),
    created_at TEXT NOT NULL
);

CREATE INDEX venue_feedback_events_venue ON venue_feedback_events(venue_id, created_at DESC);

CREATE TABLE venue_feedback_state (
    venue_id TEXT PRIMARY KEY REFERENCES venues(id) ON DELETE CASCADE,
    more_from_here INTEGER NOT NULL DEFAULT 0 CHECK (more_from_here IN (0, 1)),
    muted INTEGER NOT NULL DEFAULT 0 CHECK (muted IN (0, 1)),
    updated_at TEXT NOT NULL
);
