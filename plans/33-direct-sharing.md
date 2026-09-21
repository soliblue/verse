# Direct sharing

1. Retire the server-only share extension. Use the native audio/video document opening route to launch Verse and immediately transcribe with the selected engine, model, language, and writing style. No Verse confirmation sheet, implicit model download, or server fallback.
2. Preserve private pending audio and retry settings. Ask for iOS notification permission on the first valid import, respect an explicit notification opt-out, and use existing completion notifications/history. Keep the existing bounded background task; interrupted work remains available for retry.
3. Run `make check`, native unit/UI tests and screenshot review. Push and release the verified source to the existing internal TestFlight, then check Apple processing and internal beta availability. Source-app menu discovery and background execution remain real-phone checks.

Verified on September 21, 2026:

- `make check`: 28 backend tests passed.
- [Native CI 35586029844](https://github.com/soliblue/verse/actions/runs/35586029844) passed for `74ae0e7`: 108 unit tests, 40 UI tests, one optional real-keyboard test skipped. Cold file opening and selected-model retry screenshots reviewed. The first run exposed an XCTest background-assertion timeout; establishing the automation session before terminating the app made the cold-launch test pass.
- [Internal TestFlight release 35588053830](https://github.com/soliblue/verse/actions/runs/35588053830) uploaded version 0.3.1 (29) from `74ae0e7`. Apple confirmed `VALID`, `IN_BETA_TESTING`, and membership in `Internal` at 10:25 UTC.
- No VPS change was required. Simulator evidence verifies document delivery and preserved selection, not third-party share menu discovery or uninterrupted long-running background inference.
