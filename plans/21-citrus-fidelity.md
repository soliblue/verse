# Citrus fidelity

Status: complete, build 19 available to internal testers

## Goal

Match the selected orange reference in the native app and keyboard. Keep build 18 available and ship a separate internal TestFlight build.

## Contracts

- Preserve the VPS transcription backend, recordings, and build 18 background controls.
- No slogan. Cream recording controls, green accents, textured yellow paper.
- Generated hero artwork includes the orange, starburst, leaf, flower, and speech sticker.
- Native text and controls remain accessible and interactive.
- History is an inset paper panel rather than a full-width generic list.
- Cold keyboard dictation opens the app and starts recording immediately, with a clear return gesture. Do not claim automatic cross-app return.
- Preserve unrelated reader and event changes.

## Assets

- Reference: `plans/assets/citrus-reference.png`.
- `CitrusHero`: centered orange collage, square, built-in image generation, no UI or slogan.
- `CitrusPaper`: subtle opaque lemon risograph texture.
- `CitrusReceipt`: cream cut-paper history panel with green frame.

### Generation provenance

- Hero result: `exec-6f28b0f6-f31d-46be-9e30-57dd0f1fd308.png`. Prompt: square lemon-yellow risograph paper, centered imperfect orange cross-section, cream pith, green starburst upper-left, leaf lower-left, cream flower lower-right, cream waveform speech sticker upper-right; no text, slogan, microphone, controls, transparency, or shadows. Reference image attached.
- Paper result: `exec-cc94a1a1-29d0-48c1-b370-665bfd5128f1.png`. Prompt: subtle warm lemon-yellow paper approximately #FCE642, fine irregular fibers, understated ink grain, uniform light, opaque, no objects or borders.
- Receipt result: `exec-e41c7553-c2a8-4aa8-99e8-c02717648d71.png`. Prompt: landscape blank cream paper, thin deep-green risograph frame, punched left edge, shallow torn bottom, minimal yellow margin; no text, rules, UI, icons, perspective, or transparency.
- All artwork generated with the built-in image tool and inspected before integration. Native alpha-mask feathering blends the opaque paper edges. Native SF Symbols and editable labels remain separate from artwork.

## Verification

Native simulator captures of the hub and actual keyboard controller, unit/UI tests, visual comparison, GitHub release, and App Store Connect internal availability.

## Log

- 2026-09-05: Confirmed build 18 is already available. Inspected the selected reference and current implementation.
- 2026-09-05: Wispr Flow documentation confirms its iOS 26.4 flow may open the app and requires a bottom-bar swipe back. Verse currently only enables a session on its keyboard URL; remove that unnecessary extra step.
- 2026-09-05: Replaced unsupported keyboard NSExtensionContext opening with a genuine SwiftUI Link, following KeyboardKit's primary implementation guidance. New URL starts recording immediately and resets navigation to show return guidance. Background Control Center and Action Button remain supported alternatives. Real-device host handoff remains a verification gap.
- 2026-09-05: First native comparison found visible raster background seams and history text touching the punched paper edge. Feathered image boundaries, increased safe text inset, and made the receipt use remaining screen height. All 29 unit tests and 4 UI tests passed before these visual corrections and the cold-link addition.
- 2026-09-05: Final CI 33986445188 passed 11 backend tests, 29 native unit tests, and 5 interface tests. Revised hub, ready keyboard, and cold keyboard captures reviewed against the selected reference. Visual QA passed; actual third-party host handoff remains a phone verification gap.
- 2026-09-05: TestFlight workflow 33986865180 succeeded. App Store Connect independently reports version 0.2.0 build 19 as VALID and IN_BETA_TESTING in Internal. Build 18 was not revoked. Live health and authenticated configuration endpoints returned 200; models remain small, medium, and large-v3.

## Research

- https://docs.wisprflow.ai/articles/7453988911-set-up-the-flow-keyboard-on-iphone
- https://developer.apple.com/documentation/uikit/configuring-open-access-for-a-custom-keyboard
- https://keyboardkit.com/blog/2024/09/11/ios18-breaks-selector-based-url-opening
- https://keyboardkit.com/features/navigation

## Next keyboard direction

- Operator supplied Wispr screenshots on 2026-09-05: keep a real typing keyboard visible while idle, with a small citrus recording control at the top right. Show the recording surface only while speaking, then return to typing after insertion.
- This requires Verse's own character keyboard. iOS does not expose a way to append our control to Apple's keyboard in other apps.
- Keep the current release independent. Do not mistake the current dictation-only panel for this future typing keyboard.
