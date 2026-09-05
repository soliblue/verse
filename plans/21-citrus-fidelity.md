# Citrus fidelity

Status: implementing

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

## Verification

Native simulator captures of the hub and actual keyboard controller, unit/UI tests, visual comparison, GitHub release, and App Store Connect internal availability.

## Log

- 2026-09-05: Confirmed build 18 is already available. Inspected the selected reference and current implementation.
- 2026-09-05: Wispr Flow documentation confirms its iOS 26.4 flow may open the app and requires a bottom-bar swipe back. Verse currently only enables a session on its keyboard URL; remove that unnecessary extra step.
- 2026-09-05: Replaced unsupported keyboard NSExtensionContext opening with a genuine SwiftUI Link, following KeyboardKit's primary implementation guidance. New URL starts recording immediately and resets navigation to show return guidance. Background Control Center and Action Button remain supported alternatives. Real-device host handoff remains a verification gap.
- 2026-09-05: First native comparison found visible raster background seams and history text touching the punched paper edge. Feathered image boundaries, increased safe text inset, and made the receipt use remaining screen height. All 29 unit tests and 4 UI tests passed before these visual corrections and the cold-link addition.

## Research

- https://docs.wisprflow.ai/articles/7453988911-set-up-the-flow-keyboard-on-iphone
- https://developer.apple.com/documentation/uikit/configuring-open-access-for-a-custom-keyboard
- https://keyboardkit.com/blog/2024/09/11/ios18-breaks-selector-based-url-opening
- https://keyboardkit.com/features/navigation
