# Markdown preferences

## Goal

Make Topics one editable Markdown document so preferences can evolve without redesigning a form or transport schema.

## Status

Ready for private TestFlight deployment.

## Contracts

- `content/preferences.md` is the editable source of truth.
- The phone displays and saves the exact Markdown without regenerating it.
- Saving is explicit and survives offline through the existing SwiftData outbox.
- The VPS validates the document before atomic publication.
- SQLite stores only the derived topic projection used by deterministic ranking.
- The legacy structured Topics endpoint remains available for installed older builds.

## Log

- 2026-07-16: Replaced the structured Topics list and editor sheets with one monospaced Markdown editor.
- 2026-07-16: Added a lossless private preferences API and preserved the current parser as a safety boundary.
- 2026-07-16: Added app-wide tap-away dismissal and immediate swipe dismissal for every keyboard surface.
