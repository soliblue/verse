# Quiet Receipt

## Compact revision, September 7

1. Keep the selected unified-menu design and yellow half-sheet. Float the existing logo and icon buttons over scrolling content without a toolbar backdrop.
2. Use native List swipe deletion, compact two-line previews, and one metadata line for model, requested language, duration, time, and version count. Remove the history keyboard shortcut; retain activation in the record button's context menu.
3. Persist the displayed version independently of stable recording order. Put saved versions, per-run language, ready-model regeneration, and explicit missing-model downloads in one native menu. Preserve audio, original text, pending selections, defaults, streaming uploads, and single insertion.
4. Run backend checks and native CI. Inspect history, swipe deletion, transparent scrolling toolbar, language selection, menu, and download/cancel screenshots. Publish only the verified source to existing internal TestFlight and confirm Apple availability.

## Original scope

1. Keep the citrus artwork, pin the compact home toolbar, and widen the receipt history. Show the actual Local or Cloud model on every result. Open transcripts in a native yellow half-sheet that expands for longer text.
2. Use one model list in Settings and for retranscription. Selecting an undownloaded local model starts its download explicitly. Keep download progress, cancellation, and removal in that list. Unavailable Apple Intelligence and unconfirmed keyboard setup stay off; tapping highlights the linked setup text.
3. Group alternate results by recording, preserve the original audio and all versions, and retain engine, model, language, and writing choices through retries. A redo never changes global defaults or inserts keyboard text. Preserve server streaming, authentication, private history, and local-only processing unless Cloud is explicitly selected.
4. Run backend checks, native CI and UI screenshots. Verify sheet sizing, pinned toolbar, model selection and download states, version switching, and setup controls. Commit and push, then verify processing and internal availability in the existing TestFlight app. No public submission or infrastructure changes.

## Verification

[CI 34054040240](https://github.com/soliblue/verse/actions/runs/34054040240) passed for `6a5afbf`: 25 backend tests, 93 native tests, and 31 UI tests on the iPhone 17 Pro simulator with iOS 26.2. The optional real-extension test was not enabled. Screenshots confirmed the yellow half-sheet, shared model list, pinned toolbar, and receipt spacing.

Both setup hints visibly glow green and return to gray in the simulator recordings. Tests inspect DEBUG-only timestamps from the actual highlight transitions because XCTest waits past the one-second cue before returning from a tap. Release behavior is unchanged. Real-phone microphone handoff is not established by simulator evidence.

[TestFlight 34054828044](https://github.com/soliblue/verse/actions/runs/34054828044) uploaded version 0.3.1 (26) from `6a5afbf`. Apple confirmed `VALID`, `IN_BETA_TESTING`, and the `Internal` group on September 6, 2026.
