# Verse transcription

Status: implementing

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
