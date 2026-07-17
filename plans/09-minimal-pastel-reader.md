# Minimal pastel reader

## Goal

Remove generated covers and reduce Calendar, event detail, and root navigation to their essential interactions.

## Status

Release in progress.

## Contracts

- Article pages use a stable pastel selected from the story id.
- Nightjar does not create or require cover images.
- Calendar dates scroll horizontally; event rows open details and do not expose calendar actions.
- Event detail keeps title, description, time, and route-linked location. Secondary actions live in one top-right menu.
- Selecting any app section resets that section to its root.

## Decisions

- Preserve existing cover metadata and files as readable historical data, but stop generating and rendering them.
- Keep calendar export and feedback features, surfaced only from event detail actions.

## Log

- 2026-07-17: Started from operator screenshots and direct reduction notes.
- 2026-07-17: Replaced cover rendering with stable adaptive pastels and removed the cover generator from new editions.
- 2026-07-17: Split Nightjar guidance into core, article, and event prompts.
- 2026-07-17: Reduced Calendar to a horizontal day strip and tappable time-only event rows.
- 2026-07-17: Reduced event detail to title, time, route-linked venue, description, and one actions menu.
- 2026-07-17: Reset tab navigation paths on section changes so Settings always opens at its root.
- 2026-07-17: Fast Python, contract, shell, compile, and diff checks passed. Native iOS CI is deferred until release.
- 2026-07-17: Simulator screenshots exposed the next card beneath the bottom safe area; extended the reader viewport before TestFlight.
