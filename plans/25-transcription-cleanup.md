# Transcription-only cleanup

Status: in progress.

## Contract

Keep recording, streaming uploads, model/language choices, keyboard typing and dictation, sharing/import, history, playback, notifications, settings, Live Activities, controls, authentication, durable storage, and TestFlight signing.

Delete the retired reader, events, ETL, Nightjar, obsolete assets and documentation. Keep useful code boundaries and transcription tests. Never delete current recordings or credentials.

## Log

- 2026-09-05: Baseline 376 tracked files and 15,613 Python/Swift/shell lines. Keyboard release SHA 554182f is independently pinned to TestFlight run 33989971472. Cleanup is a separate commit.
- 2026-09-05: Removed retired iOS reader features/tests, ETL, event content, Nightjar scripts, obsolete plans/artwork, local reader databases and generated run artifacts. Current transcription data retained. Moved environment loader into speech_server and private environment to project root; updated live service and template.
- 2026-09-05: Backend tests pass, including three new environment-loading checks. Restarted service; public health 200 and anonymous config 401. Authenticated staged Medium upload completed in 10.3 seconds and its smoke record was deleted. Existing 13 completed recordings preserved; new user jobs continue arriving.
- 2026-09-05: Cleanup native build/tests pending. All 11 transcription unit tests and six UI tests remain. Runtime art remains in Shared/Assets.xcassets.
