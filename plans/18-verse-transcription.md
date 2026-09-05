# Verse transcription

Status: shipped to internal TestFlight

## Goal

Replace the reader with a private voice transcription app under the existing Verse name, bundle identifier, and TestFlight record. Keep the interface small: recordings, transcript, settings. No old research automations.

## Contracts

- The VPS runs local faster-whisper with a durable SQLite queue and one worker.
- The app defaults to the existing HTTPS endpoint. A device token is entered once and stored in Keychain.
- Audio uploads create asynchronous jobs. History and audio remain on the private server until deleted.
- The keyboard controls an explicitly activated, time-limited main-app microphone session. It never claims direct microphone access.
- The share extension uploads audio and exposes the resulting transcript.
- Shared Keychain stores extension credentials and small command/result state. No new account or app group is required.
- Light-only native interface. No reader, events, bookmarks, generated editions, or paid model APIs.
- Preserve old content and unrelated work. Ship through existing GitHub/TestFlight signing.

## Verification

Backend unit tests, real local Whisper smoke test, authenticated public API checks, GitHub iOS build and simulator smoke tests, then TestFlight upload.

## Log

- 2026-09-05: Confirmed the product pivot, inspected the old deployment, split backend and extension signing work, and started generating a minimal waveform icon. Old Nightjar jobs remain disabled.
- 2026-09-05: Implemented and deployed the authenticated speech API, installed local models, and verified public upload, completion, and deletion. Eleven backend tests pass. A 5.9-second synthetic recording took 4.3 seconds with small, 10.9 with medium, and 18.5 with large-v3 including cold loading. Small is the default.
- 2026-09-05: Registered keyboard and share bundle IDs and signed them with the existing distribution certificate and shared Keychain. No new Apple app record or App Group is needed. The first CI pass caught two main-app compile errors, both corrected. Added compressed audio capture and API decoding unit tests.
- 2026-09-05: CI run 33981406268 passed 11 backend tests, 26 native unit tests, and 3 UI tests. Inspected the hub, settings, and transcript screenshots. Verified AAC capture over ten seconds, including container overhead. Added the privacy manifest.
- 2026-09-05: TestFlight run 33982031108 signed and uploaded commit d1d8f4e. App Store Connect confirms version 0.2.0 build 17 is VALID, IN_BETA_TESTING, and included in the existing internal group with automatic notifications. The user can download it from the existing Soliverse TestFlight record.

## Operational limits

- Recordings and keyboard microphone sessions are limited to five minutes. Imported audio supports up to 50 MB and one hour.
- Keyboard dictation requires Full Access and explicit main-app activation. Actual WhatsApp interaction must be tried on the user's physical iPhone; simulator verification covers the native hub, settings, transcript, and audio encoding.
- Notifications are best effort while iOS allows polling. Accepted jobs continue on the server even if the app or share sheet closes.
- No paid transcription API, no restored research timers, and no changes to the unrelated pre-existing event worktree.
