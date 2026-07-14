# Quiet reader

## Goal

Reduce Verse to the story itself: English-only copy, light by default with a persisted appearance choice, title and text on each reader page, and sparse top actions instead of branded headers or persistent navigation chrome.

## Status

Complete.

## Contracts

- Preserve vertical paging, offline editions, refresh, saved stories, feedback, deep dives, citations, source links, topics, settings, and independent tab histories.
- Today has no wordmark header, story metadata block, pixel field, read prompt, system tab bar, or floating navigation capsule.
- Each Today page visibly contains only its title, summary, and unframed top toolbar icons.
- Full story detail visibly contains its title and body; supporting evidence and provenance move to a dedicated sheet.
- One pixel-mark menu exposes Today, Library, Topics, and Settings without persistent navigation chrome.
- Appearance follows Machtblick's persisted System, Light, and Dark choices, with Light as the missing-value default.
- SwiftUI and date formatting resolve in English regardless of device language.

## Decisions

- Keep the required `TabView` and one `NavigationStack` per tab while hiding both the system tab bar and any custom persistent dock.
- Use pull-to-refresh on Today and remove the explicit refresh header.
- Reuse one story action menu for feedback, deep-dive requests, source access, sharing, and evidence details.
- Keep 44-point action targets with no capsules, borders, or backgrounds on the reader canvas.
- Keep iOS 17 as the deployment target.

## Log

- 2026-07-14: Started the light-first, English-only, chrome-removal iteration after TestFlight build `0.1.0 (3)` became valid.
- 2026-07-14: Read Machtblick's persisted appearance, Settings picker, theme UI tests, and paged feed implementation.
- 2026-07-14: Audited Verse's reader hierarchy, navigation paths, feedback persistence, deep-dive state, locale settings, and UI smoke coverage.
- 2026-07-14: Removed the Today header, pixel field, metadata, read prompt, floating dock, and decorated action controls.
- 2026-07-14: Added the pixel navigation menu, shared story action menu, evidence sheet, English locale, and persisted light-first appearance.
- 2026-07-14: Passed contract validation and all 55 backend and Nightjar tests locally.
- 2026-07-14: Kept preloaded feed pages from being marked seen, made navigation available in every Today state, and gave every page action a stable identifier.
- 2026-07-14: Completed a read-only SwiftUI API and regression review with no remaining local blocker.
- 2026-07-14: CI build and unit tests passed; made the source-link UI assertion independent of its platform accessibility role after the first simulator run.
- 2026-07-14: The green simulator screenshots revealed the next page's toolbar at the bottom edge; consolidated reader controls into one feed-level toolbar before release.
- 2026-07-14: The consolidated toolbar passed every interaction assertion; raised the two long UI tests from 60 to 90 seconds after a slow runner completed navigation successfully at 65 seconds.
- 2026-07-14: The final iOS build, unit tests, UI smoke tests, screenshot artifacts, and backend checks passed in GitHub Actions run `29339449541`.
- 2026-07-14: Reviewed the final light and dark screenshots with one toolbar, no persistent navigation, and clean page edges.
- 2026-07-14: Uploaded private TestFlight build `0.1.0 (4)` in run `29340082098`; App Store Connect marked it valid and made it available to the internal tester.
