# Simple Verse

## Goal

Make Verse easy to understand, edit, move, and recover. Markdown is the human-readable source of truth, Nightjar prepares one finite daily edition, the VPS serves it through a tiny private API, and the iOS app caches it for offline reading.

## Status

Implemented for v0.

## Principles

- Prefer files over infrastructure.
- A person should be able to edit every important input and output with a text editor.
- Keep generated formats disposable and reproducible.
- Keep the daily edition finite at roughly 8 to 12 stories.
- Preserve original sources, dates, citations, selection reasons, and model provenance.
- Keep the app useful offline and never require a daily app release.
- Keep credentials, tunnel identifiers, tokens, and personal infrastructure configuration untracked.

## Proposed structure

```text
content/
  preferences.md
  editions/
    2026-07-15/
      edition.md
      01-story-slug.md
      02-story-slug.md
      assets/
        01-story-slug.png
  deep-dives/
    ready/
runs/
  _nightjar/
    result.json
    agent-result.json
    agent-protocol.jsonl
```

## Content contracts

### Preferences

`content/preferences.md` contains editable interests, labs, artists, techniques, venues, sources, and exclusions. Plain Markdown carries the meaning. Optional front matter holds stable identifiers and weights only when needed.

### Story

Each story is one Markdown file with optional YAML front matter for machine-readable fields:

```markdown
---
id: story-example
date: 2026-07-15
source: Example Source
url: https://example.com/original
topics: [spatial-audio, generative-media]
kind: paper
cover: assets/story-example.png
---

# Story title

Summary and article body.

## Why this was selected

Selection reason.

## Sources

- [Original source](https://example.com/original)
```

Front matter may later describe display treatment, but presentation defaults belong in the app so ordinary stories stay simple.

### Edition

`edition.md` defines the date, title, short introduction, and ordered story filenames. A generated `edition.json` may be served to iOS, but it is a build artifact rather than the editable source of truth.

### Feedback

The phone sends small mutations for seen, saved, more like this, less like this, too basic, and deep-dive requests. SQLite keeps the durable event history and current state. Nightjar receives a bounded, read-only feedback snapshot at the start of each isolated run.

## Nightjar flow

1. Read `preferences.md`, recent editions, and the private feedback snapshot.
2. Collect configured feeds and selected web research with source evidence.
3. Normalize and deduplicate before model work.
4. Rank candidates using interests, source quality, novelty, and feedback.
5. Ask a fresh agent run to prepare 8 to 12 stories and any queued deep dives.
6. Generate one restrained cover image per story when it materially improves the edition.
7. Validate links, citations, front matter, image paths, and edition size.
8. Stage the complete edition in a temporary directory.
9. Atomically publish it only after validation succeeds.
10. Preserve the previous good edition when any required stage fails.

## Cover images

- Use generated bitmap artwork rather than scraped editorial images by default.
- Keep one consistent, minimal visual language for Verse.
- Prefer abstract pixel fields, quiet spatial forms, restrained color, and generous negative space.
- Avoid text, logos, faces, literal stock imagery, and decorative noise.
- Store the generation prompt, model, dimensions, and source story identifier with each asset.
- Generate a neutral fallback locally so an image failure never blocks an edition.
- Let readers hide covers globally if the text-only experience feels better.

## VPS delivery

- Run the Verse server on localhost only.
- Route the private Verse hostname through a managed tunnel to the local server.
- Terminate TLS at the tunnel provider and require one device secret at the API.
- Keep tunnel tokens, account identifiers, certificates, and device secrets in environment files or system credential storage.
- Track only redacted examples and generic operational instructions.
- Serve current edition, edition history, assets, feedback writes, topic updates, and deep-dive requests.
- Keep the iOS app reading its local cache first and refreshing from the VPS when available.

## Simplification boundary

- Markdown is authoritative for preferences, editions, stories, and completed deep dives.
- Generated JSON is the stable transport contract for iOS.
- SQLite owns stable identities, edition membership, story relationships, feedback, deduplication, and job state.
- Keep SQLite rebuildable from Markdown wherever possible and avoid storing a second editable copy of article text.
- Do not add a CMS, user system, queue service, object store, analytics stack, or provider API dependency.

## Migration sequence

1. Define and test Markdown and front-matter contracts.
2. Export the bundled first edition and preferences into the new structure.
3. Generate the existing iOS JSON contract from Markdown without changing the app.
4. Change Nightjar to stage and publish Markdown plus assets.
5. Reduce SQLite to relationships, feedback, deduplication, and operational state.
6. Deploy the localhost server, private tunnel, and nightly timer.
7. Configure the iPhone and verify refresh, offline cache, feedback, and rollback.
8. Remove obsolete ETL and database code only after the file workflow has completed several successful runs.

## Open decisions

- Whether Git history is useful for content snapshots or simple VPS backups are sufficient.
- How long raw source evidence and agent protocol logs should be retained.

## Log

- 2026-07-15: Captured the direction to make Verse file-first, editable, private, and portable.
- 2026-07-15: Chose Markdown as the proposed source of truth and generated JSON as the iOS transport format.
- 2026-07-15: Added minimal generated cover artwork as an optional Nightjar stage with provenance and a non-blocking fallback.
- 2026-07-15: Kept tunnel and personal VPS configuration private and outside tracked files.
- 2026-07-16: Kept SQLite as the small relationship and state layer while Markdown remains the editable content source.
- 2026-07-16: Made a fresh Codex app-server thread with web and image tools the default Nightjar editor.
- 2026-07-16: Isolated agent writes to a staged content workspace and kept live publishing behind deterministic validation and materialization.
- 2026-07-16: Kept `VERSE_NIGHTJAR_MODE=etl` as the explicit model-free fallback.
- 2026-07-16: Deployed the Markdown source, generated JSON transport, SQLite feedback state, private tunnel, offline iOS cache, and nightly timer.
- 2026-07-16: Published a fresh edition with 10 stories, 18 source citations, and 10 generated covers through the validated staging and rollback path.
- 2026-07-16: Sealed the editor in a disposable container with only its staged workspace and temporary agent credentials available.
- 2026-07-16: Verified exact model provenance, bounded retries, authenticated delivery at `verse.soli.blue`, backend tests, iOS tests, simulator smoke launch, and visual screenshots.
