# Voice-only input panel

Status: release authorized. Run native CI and rendered comparison, update the existing backend without losing private data, then distribute to internal TestFlight and confirm Apple availability.

1. Make the voice-only input panel the default. Preserve the existing typing keyboard as an opt-in setting and retain its implementation and tests.
2. Build Citrus while idle and Ribbon while recording with icon-led language/model controls and comfortable touch margins. Use one native keyboard backdrop throughout, without an inset card or coloured rectangle behind the citrus. Keep the system-owned dock and appearance intact. Show power when activation is needed, waveform when ready, and stop with animated audio levels while recording.
3. Preserve app-owned capture, keyboard handoff, streaming AAC, retries, local pending recordings, Medium by default, and single-insertion guards. Keep bridge and audio-meter work off the typing/UI thread.
4. Base completion notifications on each job's actual origin. App recordings and imported/shared audio may notify under the existing permission/preference rules; keyboard or voice-panel dictation must not. Include the transcription in the notification body. Origin must survive refresh/relaunch and must not be inferred from whether a keyboard session happens to be active.
5. Add notification-origin regressions and voice-panel state/layout tests. Run `make check`, native CI, and inspect rendered evidence before any requested release. Physical microphone handoff and device FPS still require phone verification.

Verification: `make check` passes 25 tests. Native tooling cannot run on this Linux host (`xcrun` unavailable). New native tests and screenshot captures will run in GitHub CI. Backend origin metadata needs the next service restart before app distribution.

Backdrop reference: Apple's [UIInputView documentation](https://developer.apple.com/documentation/uikit/uiinputview) describes the native keyboard-matching background. Custom panel containers remain transparent rather than attempting to recolour system-owned chrome.

Artwork: `apps/ios/Shared/Assets.xcassets/CitrusSlice.imageset/slice.png`, generated with built-in ImageGen. Prompt: preserve printed orange wedges, thin cream rind and empty cream center; solid cream outside; centered slice filling the square; no icons, text, leaves, stickers, shadows or UI. Alpha generation was unavailable, so the control uses native circular clipping, never a rectangular image background.
