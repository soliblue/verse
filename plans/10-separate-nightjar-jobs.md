# Separate Nightjar jobs

## Goal

Make Articles and Events independent research products with small editable guidance documents and native controls in Verse.

## Status

Implemented locally. Native iOS build and device deployment remain release steps.

## Contracts

- The articles agent writes one 8 to 12 item edition and never writes event items.
- The events agent refreshes upcoming events, archives ended events, and maintains verified public place facts.
- A long-running exhibition may appear once as an article when the editorial value is awareness rather than attendance at a dated occurrence.
- `content/prompts/articles.md` and `content/prompts/events.md` are operator-editable guidance, not replacements for format, evidence, safety, or output rules.
- The authenticated API can read and update either guidance document and trigger either bounded systemd job.
- Settings exposes two guidance editors and two run actions without adding a new tab or page header.
- Articles defensively filters historical event stories.

## Decisions

- Keep checked-in prompts as the stable contract and private content prompts as editable taste guidance.
- Keep one global Nightjar lock because both jobs publish the same content tree and SQLite materialization.
- Keep the nightly timer running both jobs sequentially in one protected publication transaction.
- Use native Form rows and an item-driven editor sheet.

## Log

- 2026-07-17: Confirmed the existing prompt files were concatenated into one agent call.
- 2026-07-17: Started the job, API, and Settings split.
- 2026-07-17: Split the runner into independent article and event agent sessions with scoped validation and one publication lock.
- 2026-07-17: Added editable Markdown guidance, authenticated guidance and run endpoints, and bounded systemd job units.
- 2026-07-17: Reduced Settings to VPS and Nightjar, locked Verse to light mode, restored native story navigation, and fixed Calendar gesture competition.
- 2026-07-17: `make check` passed 84 tests plus contract, Python, and shell validation.
