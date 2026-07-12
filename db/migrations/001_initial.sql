CREATE TABLE settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE topics (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    kind TEXT NOT NULL CHECK (kind IN ('interest', 'lab', 'artist', 'source', 'venue', 'exclusion')),
    description TEXT NOT NULL,
    is_enabled INTEGER NOT NULL CHECK (is_enabled IN (0, 1)),
    position INTEGER NOT NULL CHECK (position >= 0),
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE UNIQUE INDEX topics_position ON topics(position);

CREATE TABLE source_items (
    id TEXT PRIMARY KEY,
    source_id TEXT NOT NULL,
    external_id TEXT NOT NULL,
    source_name TEXT NOT NULL,
    title TEXT NOT NULL,
    url TEXT NOT NULL,
    author TEXT,
    published_at TEXT,
    content TEXT NOT NULL,
    citations_json TEXT NOT NULL,
    topic_ids_json TEXT NOT NULL,
    raw_json TEXT NOT NULL,
    content_hash TEXT NOT NULL,
    collected_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    UNIQUE (source_id, external_id)
);

CREATE INDEX source_items_url ON source_items(url);
CREATE INDEX source_items_published_at ON source_items(published_at);

CREATE TABLE normalized_items (
    id TEXT PRIMARY KEY,
    source_item_id TEXT NOT NULL UNIQUE REFERENCES source_items(id),
    canonical_url TEXT NOT NULL,
    title TEXT NOT NULL,
    author TEXT,
    source_name TEXT NOT NULL,
    published_at TEXT,
    content TEXT NOT NULL,
    citations_json TEXT NOT NULL,
    topic_ids_json TEXT NOT NULL,
    evidence_json TEXT NOT NULL,
    content_hash TEXT NOT NULL,
    normalized_at TEXT NOT NULL
);

CREATE INDEX normalized_items_canonical_url ON normalized_items(canonical_url);
CREATE INDEX normalized_items_published_at ON normalized_items(published_at);

CREATE TABLE etl_runs (
    id TEXT PRIMARY KEY,
    edition_date TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('running', 'completed', 'failed')),
    current_stage TEXT,
    started_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    completed_at TEXT,
    error TEXT
);

CREATE TABLE etl_stage_results (
    run_id TEXT NOT NULL REFERENCES etl_runs(id) ON DELETE CASCADE,
    stage TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('running', 'completed', 'failed')),
    row_count INTEGER,
    started_at TEXT NOT NULL,
    completed_at TEXT,
    error TEXT,
    PRIMARY KEY (run_id, stage)
);

CREATE TABLE run_source_items (
    run_id TEXT NOT NULL REFERENCES etl_runs(id) ON DELETE CASCADE,
    source_item_id TEXT NOT NULL REFERENCES source_items(id),
    PRIMARY KEY (run_id, source_item_id)
);

CREATE TABLE run_normalized_items (
    run_id TEXT NOT NULL REFERENCES etl_runs(id) ON DELETE CASCADE,
    normalized_item_id TEXT NOT NULL REFERENCES normalized_items(id),
    PRIMARY KEY (run_id, normalized_item_id)
);

CREATE TABLE run_candidates (
    run_id TEXT NOT NULL REFERENCES etl_runs(id) ON DELETE CASCADE,
    normalized_item_id TEXT NOT NULL REFERENCES normalized_items(id),
    dedupe_key TEXT NOT NULL,
    duplicate_of TEXT REFERENCES normalized_items(id),
    source_quality REAL,
    interest_score REAL,
    novelty_score REAL,
    feedback_score REAL,
    total_score REAL,
    selected INTEGER NOT NULL DEFAULT 0 CHECK (selected IN (0, 1)),
    rationale TEXT,
    PRIMARY KEY (run_id, normalized_item_id)
);

CREATE INDEX run_candidates_rank ON run_candidates(run_id, selected, total_score DESC);

CREATE TABLE draft_stories (
    run_id TEXT NOT NULL REFERENCES etl_runs(id) ON DELETE CASCADE,
    story_id TEXT NOT NULL,
    normalized_item_id TEXT NOT NULL REFERENCES normalized_items(id),
    position INTEGER NOT NULL,
    payload_json TEXT NOT NULL,
    evidence_json TEXT NOT NULL,
    model_provenance_json TEXT NOT NULL,
    PRIMARY KEY (run_id, story_id),
    UNIQUE (run_id, position)
);

CREATE TABLE run_deep_dives (
    run_id TEXT NOT NULL REFERENCES etl_runs(id) ON DELETE CASCADE,
    story_id TEXT NOT NULL,
    payload_json TEXT NOT NULL,
    model_provenance_json TEXT NOT NULL,
    PRIMARY KEY (run_id, story_id)
);

CREATE TABLE stories (
    id TEXT PRIMARY KEY,
    source_name TEXT NOT NULL,
    source_url TEXT NOT NULL,
    published_at TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE editions (
    id TEXT PRIMARY KEY,
    edition_date TEXT NOT NULL UNIQUE,
    title TEXT NOT NULL,
    dek TEXT NOT NULL,
    generated_at TEXT NOT NULL,
    item_count INTEGER NOT NULL,
    payload_json TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE INDEX editions_date ON editions(edition_date DESC);

CREATE TABLE edition_items (
    edition_id TEXT NOT NULL REFERENCES editions(id) ON DELETE CASCADE,
    story_id TEXT NOT NULL REFERENCES stories(id),
    position INTEGER NOT NULL,
    evidence_json TEXT NOT NULL,
    model_provenance_json TEXT NOT NULL,
    PRIMARY KEY (edition_id, story_id),
    UNIQUE (edition_id, position)
);

CREATE TABLE feedback_state (
    story_id TEXT PRIMARY KEY REFERENCES stories(id),
    saved INTEGER NOT NULL DEFAULT 0 CHECK (saved IN (0, 1)),
    seen INTEGER NOT NULL DEFAULT 0 CHECK (seen IN (0, 1)),
    preference TEXT CHECK (preference IN ('more_like_this', 'less_like_this', 'too_basic')),
    updated_at TEXT
);

CREATE TABLE feedback_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    story_id TEXT NOT NULL REFERENCES stories(id),
    kind TEXT NOT NULL CHECK (kind IN ('saved', 'seen', 'more_like_this', 'less_like_this', 'too_basic')),
    value INTEGER NOT NULL CHECK (value IN (0, 1)),
    created_at TEXT NOT NULL
);

CREATE INDEX feedback_events_story ON feedback_events(story_id, created_at DESC);

CREATE TABLE deep_dives (
    story_id TEXT PRIMARY KEY REFERENCES stories(id),
    status TEXT NOT NULL CHECK (status IN ('queued', 'ready', 'failed')),
    requested_at TEXT NOT NULL,
    title TEXT,
    body TEXT,
    citations_json TEXT NOT NULL,
    model_provenance_json TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
