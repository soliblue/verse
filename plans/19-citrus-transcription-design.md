# Citrus transcription design

## Goal

Implement the selected second visual direction in the existing native app and keyboard.

## Status

Code and asset prepared. Native build and visual verification blocked on unavailable Xcode. No commit, push, or distribution performed in this iteration.

## Contracts and decisions

- Keep the transcription backend, persistence, and recording state machine unchanged.
- Lemon canvas, original orange cutout, cream recording controls, dark ink, green accents.
- Remove the slogan. No generated text or icons inside the artwork.
- Preserve imports, history, errors, pending uploads, settings, and keyboard insertion.
- Use existing SF Symbols and native accessible controls.
- Preserve unrelated reader and event changes.

## Log

- 2026-09-05: User selected option 2 and requested no slogan and a better recording button. Asset generation and keyboard styling delegated independently; main agent owns hub and integration.
- 2026-09-05: Added original citrus artwork to shared assets, cream microphone controls, integrated history, and compact keyboard with conditional globe. Preserved recording state machine and insertion behavior.
- 2026-09-05: Image tool did not produce alpha despite repeated requests. Final raster uses a matching lemon field, native circular clipping, no rotation. Inspect edges in simulator before acceptance.
- 2026-09-05: `git diff --check` passed. Xcode simulator discovery failed with `spawn xcrun ENOENT`. Design QA remains blocked pending GitHub native build and screenshots.

## Image provenance

Built-in image generation produced `apps/ios/Shared/Assets.xcassets/Citrus.imageset/citrus.png` from the selected design reference. No external image API or credentials used.

Final prompt: Generate a new square production illustration of one front-on orange cross-section, centered at 85 percent of frame. Thin cream rind, irregular saturated orange pulp, small natural cream pith. Flat risograph texture inside the fruit. Uniform lemon yellow background RGB 255,240,102. No text, UI, icons, buttons, leaves, stickers, stars, slogans, shadows, or 3D. Reference is the selected citrus mockup.
