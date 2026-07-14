# Full-screen reader

## Goal

Turn Verse into a quiet, full-screen morning reader with one story per vertical page, native snap scrolling, minimal floating navigation, and a pixel-universe identity.

## Status

In progress.

## Contracts

- Preserve the bundled edition, offline cache, refresh, feedback, deep dives, library, topics, and settings behavior.
- Today uses one viewport per story with stable story identity and native vertical paging on iOS 17.
- The main reader has no system navigation bar or tab bar.
- Floating controls stay outside the story navigation hit target and respect safe areas.
- Long body text, citations, and feedback remain in a dedicated detail surface rather than a nested reader scroll view.
- Typography, spacing, and color follow the restrained Machtblick iOS system without adding a runtime dependency.
- The app mark and icon use one minimal pixel-universe motif with no word inside the icon.
- UI tests cover launch, paging, the floating dock, and settings access.

## Decisions

- Keep the existing `TabView` and one `NavigationStack` per surface, hide the system tab bar, and provide a compact floating dock.
- Reuse Machtblick's `ScrollView`, zero-spacing `LazyVStack`, `containerRelativeFrame`, `scrollTargetLayout`, and paging composition.
- Keep the deployment target at iOS 17 and avoid iOS 18 or iOS 26-only scroll and toolbar APIs.
- Use Fraunces for display titles, Lora for reading text, and system monospaced labels for utility metadata.
- Use adaptive black and white surfaces with one restrained violet accent.

## Log

- 2026-07-14: Started the visual redesign after private TestFlight build `0.1.0 (2)` became valid.
- 2026-07-14: Audited the Machtblick iOS paging feed, card composition, type system, theme tokens, and toolbar behavior.
- 2026-07-14: Replaced the Today list with stable-ID full-screen story pages using native vertical paging.
- 2026-07-14: Replaced the system tab bar with a safe-area floating dock and hid it on pushed story surfaces.
- 2026-07-14: Added the pixel-orbit mark, adaptive monochrome theme, violet accent, and bundled Fraunces and Lora type system.
- 2026-07-14: Reworked story detail into a chrome-free reading surface with floating back, save, and share controls.
- 2026-07-14: Updated fixture and UI smoke coverage for paging, story navigation, and floating settings access.
- 2026-07-14: Replaced the sunrise-and-book icon with an opaque nine-pixel orbit icon generated from the new identity direction and normalized to the app palette.
- 2026-07-14: Local contracts and all 55 Python tests passed.
- 2026-07-14: Added a compact short-screen page composition, corrected small-text contrast, made feedback controls wrap safely, and honored Reduce Motion.
- 2026-07-14: Made UI coverage content-independent and added Library and Topics dock checks.
- 2026-07-14: Isolated accessibility identifiers from SwiftUI's hidden native tab items and parent identifier propagation after the first UI run exposed ambiguous controls.
- 2026-07-14: Increased the unit runner allowance after all 9 tests passed but Xcode 26's simulator harness crossed the previous 10-minute step ceiling.
- 2026-07-14: Simulator screenshots exposed a doubled native and custom dock; moved tab-bar hiding into each navigation stack and added a one-button-per-tab regression check.
