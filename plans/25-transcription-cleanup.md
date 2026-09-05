# Transcription-only cleanup

Status: complete, committed, pushed, and verified.

## Contract

Keep recording, streaming uploads, model/language choices, keyboard typing and dictation, sharing/import, history, playback, notifications, settings, Live Activities, controls, authentication, durable storage, and TestFlight signing.

Delete the retired reader, events, ETL, Nightjar, obsolete assets and documentation. Keep useful code boundaries and transcription tests. Never delete current recordings or credentials.

## Log

- 2026-09-05: Baseline 376 tracked files and 15,613 Python/Swift/shell lines. Keyboard release SHA 554182f is independently pinned to TestFlight run 33989971472. Cleanup is a separate commit.
- 2026-09-05: Removed retired iOS reader features/tests, ETL, event content, Nightjar scripts, obsolete plans/artwork, local reader databases and generated run artifacts. Current transcription data retained. Moved environment loader into speech_server and private environment to project root; updated live service and template.
- 2026-09-05: Backend tests pass, including three new environment-loading checks. Restarted service; public health 200 and anonymous config 401. Authenticated staged Medium upload completed in 10.3 seconds and its smoke record was deleted. Existing 13 completed recordings preserved; new user jobs continue arriving.
- 2026-09-05: Cleanup native build/tests pending. All 11 transcription unit tests and six UI tests remain. Runtime art remains in Shared/Assets.xcassets.
- 2026-09-05: Cleanup commits 4a81adf and 891acdd pushed. Tracked files reduced from 376 to 85; Python/Swift/shell lines from 15,613 to 3,701. CI 33990355599 passed backend, native build, unit tests, and UI tests; screenshot export is finishing. Keyboard fix independently available as TestFlight build 21.
- 2026-09-05: CI 33990355599 completed successfully: 24 backend tests, 11 native unit tests, six UI tests, screenshot export. Inspected the cleaned app hub and compact keyboard screenshots; runtime artwork and controls remain intact. No second binary needed for removal of unreachable legacy source.
