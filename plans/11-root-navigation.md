# Root navigation

## Goal

Make every pixel-menu destination a true root screen without an automatic More or back button.

## Status

In progress.

## Decision

The pixel menu switches directly between one `NavigationStack` per destination. Verse does not use a hidden `TabView` because six hidden tabs invoke iOS's automatic More controller.

## Verification

- Topics and Settings have neither Back nor More buttons.
- Story and event detail keep native back navigation.
- The full iOS CI and TestFlight workflows pass.

## Log

- 2026-07-17: Replaced the six-item hidden `TabView` with direct root switching and added UI regression checks.
