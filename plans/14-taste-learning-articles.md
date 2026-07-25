# Taste-learning articles

## Goal

Replace the old article editions with a fresh reader driven by ranked examples and explicit likes.

## Status

Complete.

## Contracts

- Articles use the fixed editor prompt, `content/prompts/articles.md`, ranked `content/article-examples.md`, liked stories, and a complete shown-story index.
- Topics and event feedback never steer article research.
- A source URL or normalized title already shown cannot be published again.
- Like is the single positive taste signal and becomes a full prompt example on later runs.
- Article Markdown may reference one local generated visual in its edition assets.
- Events remain independent.

## Decisions

- Keep the learning loop inspectable instead of adding embeddings or another database.
- Build liked examples and shown-story history from SQLite at workspace preparation time.
- Keep visuals optional, local, and source-backed.
- Remove Topics from Settings because it no longer controls Articles.

## Log

- 2026-07-25: Started the ranked-example article reset and rich-reader iteration.
- 2026-07-25: Added liked-story prompt examples and a hard shown-title and source exclusion list.
- 2026-07-25: Added authenticated, offline-cached article visuals and a direct Like action.
- 2026-07-25: Published an 11-story edition with 19 citations and removed seven old editions.
- 2026-07-25: Passed 89 Python tests and verified the live API exposes only the July 25 edition.
- 2026-07-25: Added the Italo Siemens deal as ranked example 7 and replaced cryptic headline guidance with concrete, practical explanatory writing rules.
- 2026-07-25: Replaced the live edition with 11 newly researched plain-language stories after reviewing every headline and summary.
