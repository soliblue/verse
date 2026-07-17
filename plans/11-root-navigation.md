# Root navigation

## Goal

Make every pixel-menu destination a true root screen without an automatic More or back button.

## Status

Complete.

## Decision

The pixel menu switches directly between one `NavigationStack` per destination. Verse does not use a hidden `TabView` because six hidden tabs invoke iOS's automatic More controller.

## Verification

- Topics and Settings have neither Back nor More buttons.
- Story and event detail keep native back navigation.
- The full iOS CI and TestFlight workflows pass.

## Log

- 2026-07-17: Replaced the six-item hidden `TabView` with direct root switching and added UI regression checks.
- 2026-07-17: CI run `29566986460` passed backend checks, native build, unit tests, UI tests, smoke launch, and screenshot capture.
- 2026-07-17: TestFlight run `29567913981` uploaded build 9, which Apple validated and made available to the Internal group.
