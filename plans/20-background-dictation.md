# Background dictation

## Goal

Start and stop Verse dictation from system controls while staying in another app. Preserve the private VPS and local Whisper pipeline. Release the approved citrus design with this change through GitHub and internal TestFlight.

## Status

Implementation and signing in progress.

## Contracts

- One app-owned recording service shared by the UI and App Intents.
- Audio recording intent plus Live Activity, never microphone access inside the keyboard extension.
- One-time microphone permission and device token setup in Verse.
- Explicit user activation and visible microphone/session state with an end action.
- Keyboard sends start/stop to an active app recording session and inserts only a newly completed dictation once.
- Existing VPS token, upload, history, Whisper models and language settings stay unchanged.
- Do not use undocumented host-app discovery or return URLs.
- Preserve unrelated retired reader/event changes.

## Verification

GitHub signing-free build, unit and UI tests, screenshot inspection, profile validation, TestFlight upload and processing status. Simulator checks cannot establish physical microphone behavior in third-party apps; report that remaining device check honestly.

## Log

- 2026-09-05: User explicitly requested implementation, GitHub push and TestFlight deployment. Intents/widget wiring and signing delegated; main owns recording lifecycle, keyboard completion, integration and release.
- 2026-09-05: Implemented iOS 18 background toggle intent, Control Center control, Siri/Action Button shortcut, visible Live Activity, explicit end action, configurable 5/15/60-minute ready window, and keyboard-side result polling with once-only fresh-result insertion. Existing backend unchanged; all 11 backend tests pass. Registered controls extension and stored its matching distribution profile in GitHub secrets.
