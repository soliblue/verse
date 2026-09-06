# Verse

Private, single-user iPhone transcription app. Keep `soli.verse` and its existing internal TestFlight distribution. No account, paid provider, analytics, or public submission.

## Structure

- `apps/ios/src/Features/Transcription/{UI,Logic}`: recording, import, history, playback, settings.
- `apps/ios/{Keyboard,Share,Widget,Shared}`: typing and dictation keyboard, audio sharing, Live Activities, controls, shared Keychain state.
- `speech_server`: authenticated HTTP API, SQLite jobs, private audio, one bounded local faster-whisper worker.
- `scripts`: service template, upload verification, model benchmarking.

## Contracts

- Preserve streaming AAC uploads, integrity checks, idempotent retries, local pending recordings, and single-insertion guards.
- Default recognition is Medium. No provider API or automatic model downloads.
- Keyboard extensions cannot record directly. The app owns capture; active sessions permit keyboard control. Cold power opens the app. Ready sessions default to 15 minutes, selectable 5/15/60. Idle audio is discarded.
- Keep credentials in root `.env`, Keychain, or GitHub secrets. Never commit them. Current recordings and SQLite data under `db/` are private and must survive cleanup/deployment.
- The VPS service binds to loopback behind the existing HTTPS tunnel and authenticates with a device token. Do not alter shared infrastructure or access controls.
- Reader, events, and Nightjar are retired. Do not restore their automations.

## Working rules

- Be concise. Less is more; preserve useful responsibility boundaries.
- UI is presentation; loading and state belong in logic. Prefer native controls, async/await, and Observation.
- No inline comments, docstrings, decorative headers, em dashes, speculative abstractions, or new try-catch blocks.
- Root sessions integrate and verify. Delegate independent work when useful.
- Keep a concise numbered plan for nontrivial changes, including contracts and verification.
- Preserve unrelated changes. Soli authorizes committing, pushing, and deploying completed Verse iterations after verification to the existing VPS and internal TestFlight. No public submission or unrelated infrastructure changes.
- Run `make check`, then GitHub CI for native unit tests, UI tests, builds, and screenshot evidence. Device-only microphone handoff requires real-phone verification; simulator fixtures do not prove it.
- TestFlight upload success is not availability. Verify Apple processing and internal beta state before claiming a release is ready.

See `README.md` for setup and `speech_server/README.md` for the API contract.
