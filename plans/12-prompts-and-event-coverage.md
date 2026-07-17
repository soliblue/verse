# Prompts and event coverage

## Goal

Put all editable research prompts in Settings and make the daily Berlin calendar complete enough to trust.

## Status

Implemented. CI and deployment pending.

## Decisions

- Topics, Articles, and Events live together under Settings > Prompts.
- Topics is no longer a root pixel-menu destination.
- Every watched official calendar is checked daily.
- Calendar completeness is independent from featured ranking.
- This VPS uses the trusted-host local Nightjar runtime because its Docker sudo path is unavailable.

## Verification

- Settings opens all three prompt editors without a navigation back button.
- The pixel menu has five root destinations and no Topics entry.
- The unattended timer preflight passes.
- A fresh event run publishes verified Humboldt Forum and The Dark Rooms coverage.
- CI, TestFlight, the VPS health check, and the Internal group all pass.

## Log

- 2026-07-17: Found the unattended Nightjar run failed during container preflight and expanded the watched-place and event completeness contracts.
- 2026-07-17: Published 42 verified calendar occurrences, 12 featured events, and a complete 14-place research audit.
- 2026-07-17: Local checks passed with 85 tests and valid content contracts.
