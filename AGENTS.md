# Verse

Verse is a private, single-user iOS reader. It gathers material matching the operator's interests, prepares a finite morning edition on a VPS while they sleep, and supports deeper research when useful. It is a personal tool, not a SaaS and not intended for public App Store release.

## Product

- Cover high-level items plus optional deep dives.
- Initial interests include audiovisual techniques, new papers from selected labs, and relevant events in Berlin.
- A daily edition should contain roughly 8 to 12 high-signal items, not an infinite feed.
- Every item keeps its original link, source, publication date, citations, and a short explanation of why it was selected.
- Feedback includes saved, seen, more like this, less like this, too basic, and request deep dive.
- Deep-dive requests may be queued for the next nightly run.
- The working product name is Verse. The overnight worker may be called Nightjar.

## v0

- Native SwiftUI app with Today, Library, Topics, and minimal Settings surfaces.
- Today shows the current edition. Story detail shows the summary, citations, source links, selection reason, feedback, and deep-dive state.
- Library contains saved items and previous editions.
- Topics is an editable set of interests, labs, artists, sources, venues, and exclusions.
- The app fetches prepared data from the VPS and remains readable offline through a local cache.
- No registration, login UI, user table, multi-tenancy, analytics, ads, social features, SEO, or public publishing work.
- No push notifications in v0. Refresh when the app opens and on manual request.
- Private access can use Tailscale or one device secret. Never commit credentials.

## Architecture

```text
apps/ios/             Native reader
server/               Small private read and feedback API
db/                   SQLite schema and migrations
etl/                   Collect, normalize, deduplicate, rank, and write
prompts/               Versioned editor, summary, and deep-dive prompts
scripts/               Scheduler, preflight, and systemd units
plans/                 Numbered implementation plans
runs/                  Ignored nightly logs and artifacts
```

- SQLite is the source of truth. Serve materialized edition payloads rather than asking the model during reads.
- Keep source collection separate from ranking and writing. Jobs must be idempotent and resumable.
- The nightly VPS timer uses a lock, preflight, bounded runtime, inspectable result files, and a fresh agent run.
- Prefer local agent CLIs for LLM work: `codex exec`, or `claude -p` when explicitly useful. Keep the provider replaceable. Do not require provider API keys for v0.
- Use explicit user interests, source quality, novelty, and feedback for ranking. Deduplicate before model work.
- Store source evidence and model provenance with generated text. Never invent citations.
- A failed enrichment must not corrupt the previous good edition.

## iOS

- Follow `apps/ios/src/{Core,Features}` with `Features/<Name>/{UI,Logic}`.
- Use `TabView` with a `NavigationStack` per tab, modern Observation, async/await, and SwiftData caching.
- UI files contain presentation. Logic files contain loading, filtering, and state. Keep one primary type per file.
- Prefer small views, native controls, explicit loading and error states, and zero dependencies until a dependency clearly earns its place.
- GitHub Actions owns signing-free builds, simulator smoke launches, and screenshot artifacts. Private TestFlight or ad-hoc signing can be added when the operator provides keys. Never submit publicly unless explicitly requested.

## Working Rules

- Less is more. If it is not load-bearing, remove it.
- Root sessions act as lead. Subagents are allowed and preferred when delegation materially helps. Integrate by reading files and command output, not by trusting summaries alone.
- For nontrivial work, create or update `plans/NN-slug.md` with goal, status, contracts, decisions, and an append-only log.
- No inline comments, docstrings, decorative headers, em dashes, or large mixed-responsibility files.
- No try-catch unless explicitly requested. Let unexpected errors propagate to the job boundary and be recorded there.
- Avoid single-use helpers and premature shared packages. Add shared code only after a second real use.
- Prefer predictable folders, explicit imports, happy-path structure, and type-safe contracts.
- No absolute filesystem paths in checked-in files.
- Secrets stay in environment files, system credential storage, GitHub secrets, or the iOS Keychain. Commit only examples with fake values.
- Fix malformed data in collectors, normalization, or migrations, not in the read path. Every correction must be reproducible on the next refresh.
- Preserve unrelated operator changes. Never deploy, distribute, rotate keys, or commit unless explicitly asked.
- Verify proportionally: formatter and unit checks locally, then the GitHub Actions iOS build and simulator smoke test.

## Machtblick Reference

Machtblick is the implementation reference, not a runtime dependency. Read `../machtblick/AGENTS.md` and reuse patterns from `../machtblick/apps/ios`, `../machtblick/.github/workflows/ios-build.yml`, `../machtblick/scripts/scheduled-bundestag-auto-refresh`, and `../machtblick/scripts/codex_app_thread.py`. This file wins when Verse differs, especially around single-user scope, private distribution, SQLite simplicity, and the absence of publishing requirements.
