# Voice-only input panel

Status: complete. Verse 0.3.1 build 23 is `VALID` and `IN_BETA_TESTING` for the existing Internal group, confirmed with Apple on 2026-09-06 at 08:50 UTC. [Release run 34022789615](https://github.com/soliblue/verse/actions/runs/34022789615) uploaded source `da168d9`.

1. Make the voice-only input panel the default. Preserve the existing typing keyboard as an opt-in setting and retain its implementation and tests.
2. Build Citrus while idle and Ribbon while recording with icon-led language/model controls and comfortable touch margins. Use one native keyboard backdrop throughout, without an inset card or coloured rectangle behind the citrus. Keep the system-owned dock and appearance intact. Show power when activation is needed, waveform when ready, and stop with animated audio levels while recording.
3. Preserve app-owned capture, keyboard handoff, streaming AAC, retries, local pending recordings, Medium by default, and single-insertion guards. Keep bridge and audio-meter work off the typing/UI thread.
4. Base completion notifications on each job's actual origin. App recordings and imported/shared audio may notify under the existing permission/preference rules; keyboard or voice-panel dictation must not. Include the transcription in the notification body. Origin must survive refresh/relaunch and must not be inferred from whether a keyboard session happens to be active.
5. Add notification-origin regressions and voice-panel state/layout tests. Run `make check`, native CI, and inspect rendered evidence before any requested release. Physical microphone handoff and device FPS still require phone verification.

Verification: `make check` passes 25 tests. Final native CI 34022056346 passes 52 unit tests and all 17 UI tests on source `da168d9`. Rendered comparison passes after correcting the cold-activation target, toolbar gap and processing-spinner contrast. See `design-qa.md`. The backend is restarted and healthy: authenticated live streaming tests pass for app, shared and keyboard origins; all 17 existing records remain unchanged, with a private SQLite backup.

Backdrop reference: Apple's [UIInputView documentation](https://developer.apple.com/documentation/uikit/uiinputview) describes the native keyboard-matching background. Custom panel containers remain transparent rather than attempting to recolour system-owned chrome.

Artwork: `apps/ios/Shared/Assets.xcassets/CitrusSlice.imageset/slice.png`, generated with built-in ImageGen. Prompt: preserve printed orange wedges, thin cream rind and empty cream center; solid cream outside; centered slice filling the square; no icons, text, leaves, stickers, shadows or UI. Alpha generation was unavailable, so the control uses native circular clipping, never a rectangular image background.
