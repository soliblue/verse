# Background dictation

## Goal

Start and stop Verse dictation from system controls while staying in another app. Preserve the private VPS and local Whisper pipeline. Release the approved citrus design with this change through GitHub and internal TestFlight.

## Status

Released internally as version 0.2.0 build 18. Native CI passed. Physical-device background recording remains the user's beta check.

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
- 2026-09-05: CI run 33984258269 passed for 94c8051, all native targets compile, 29 unit tests and 3 UI tests pass. Fixed UIKit responder-name collision and session/poll teardown races. Public authenticated backend check passed with small, medium and large-v3 available. TestFlight run 33984878326 dispatched for the verified commit.
- 2026-09-05: Native hub screenshot saved at `plans/evidence/citrus-hub.png`. Physical-device Control Center/Action Button recording and keyboard insertion remain an explicit beta verification step; simulator tests do not establish them.
- 2026-09-05: TestFlight run 33984878326 successfully signed and uploaded verified commit 94c8051. App Store Connect API confirms version 0.2.0 build 18 is VALID, IN_BETA_TESTING and included in the Internal group. No public App Store submission. The new extension and existing app/keyboard/share targets all passed distribution signing.
