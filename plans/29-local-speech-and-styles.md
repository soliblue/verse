# Local speech and writing styles

1. Add WhisperKit as the default recording engine, with Medium selected and explicit model downloads. Keep the authenticated VPS option, streaming AAC uploads, pending audio, playback, history and retry identity. No paid providers or automatic model downloads.
2. Add optional Original, Casual, Polished and Custom writing styles using Apple's on-device model. Hide style controls when unavailable, explain the exact Apple Intelligence setting, recheck on return, preserve originals and fall back safely for unsupported languages or failed generation.
3. Hide the keyboard's first presentation until its host geometry matches the requested input height. Preserve the system backdrop, native width, typing mode and single insertion. Do not use a timed startup delay.
4. Run backend checks and native unit/UI tests in GitHub CI. Inspect Settings and keyboard transition evidence, then upload to the existing internal TestFlight and verify Apple processing and beta availability. Real-phone model speed and extension handoff remain device checks.

Released September 6, 2026: **0.3.1 (25)**, source `023e320`, [internal upload](https://github.com/soliblue/verse/actions/runs/34033956029). Apple confirmed `VALID`, `IN_BETA_TESTING`, and membership in `Internal`.

[Release CI](https://github.com/soliblue/verse/actions/runs/34033109794) passed 86 native tests, 24 UI tests, and 25 backend tests. This included an explicit Tiny download and real reference-audio transcription, signed shared-Keychain verification, and Settings screenshots. Medium speed, Apple model output, microphone handoff, and physical-phone keyboard transitions still require device checks. The VPS and private recordings were not changed.

[Follow-up CI](https://github.com/soliblue/verse/actions/runs/34034114114) passed the normal checks again. Its optional real-extension test skipped during Settings setup, so it does not prove the flash is resolved. The Settings button selector was corrected afterward but has not been rerun. Post-release changes are tests and these notes only; build 25 contains all application changes.
