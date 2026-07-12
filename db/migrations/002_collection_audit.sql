CREATE TABLE etl_source_results (
    run_id TEXT NOT NULL REFERENCES etl_runs(id) ON DELETE CASCADE,
    source_id TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('completed', 'failed')),
    item_count INTEGER NOT NULL,
    error TEXT,
    started_at TEXT NOT NULL,
    completed_at TEXT NOT NULL,
    PRIMARY KEY (run_id, source_id)
);
