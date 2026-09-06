# Voice panel visual verification

final result: blocked

Source visual truth: `/home/soli/.codex/generated_images/019f5649-2a8e-7f41-9ab5-56f5b5b7bbeb/exec-3e149905-070b-4263-98e8-bda9d1ada2df.png`, Citrus (2) idle and Ribbon (3) recording. The user's latest instruction replaces the mockup's card background with one continuous native keyboard backdrop.

Implementation: [native CI 34020577711](https://github.com/soliblue/verse/actions/runs/34020577711), source `f30b6e8`. Screenshots are in `/tmp/verse-voice-evidence-34020577711/evidence/verse-smoke/`. This is the actual UIKit input controller hosted by a simulator text field, not a web replica. Xcode runs in GitHub because this host is Linux.

Viewport: iPhone 17 Pro, iOS 26.2, 402 by 874 points at 3x. Native captures are 1206 by 2622 pixels. The app-owned input area is the bottom 1206 by 780 pixels, normalized to 402 by 260 points. Unit tests also cover 320- and 440-point widths. The extension-only system dock is outside this fixture's evidence.

Reference: 1448 by 1086 pixels, four concepts. Citrus was cropped at `(766,90,634,446)` and Ribbon at `(46,628,635,304)`, then normalized to 402 points wide without stretching. Both source and implementation are letterboxed to 402 by 284 for comparison. The mock concepts have different heights; the implementation consistently uses 260 points. Background differences follow the user's explicit native-backdrop instruction.

Full-panel comparisons: `/tmp/verse-idle-reference-comparison.png` and `/tmp/verse-recording-reference-comparison.png`. Controls, artwork edges and time are legible at this normalized size, so a separate zoom is unnecessary. Ready, cold, recording, processing, dark and retained-typing captures were collected. Recording input is synthetic, not microphone/FPS evidence.

Fidelity review:

1. Typography: native symbols and 17-point monospaced time match the restrained direction. `AUTO` replaces the mock's `EN` because automatic language is the configured default. No unwanted headings or instructional copy.
2. Spacing: centered 176-point citrus and 16-point outer margins match the composition. The first pass exposed crowded 2-point gaps between the 44-point language/model targets. Increased to 8 points in voice mode; typing remains unchanged.
3. Colours: light and dark captures show a continuous native material across the app-owned input area. Orange foregrounds remain visible. Physical extension docking still needs phone verification.
4. Artwork: printed citrus, empty cream center and circular mask are faithful to the selected direction. No rectangular image background or visible halo in either theme.
5. Content: power when cold, wave when ready, stop and elapsed time while recording. Processing is icon-only. The recording trace and timestamp naturally differ from the mock.

Findings and comparison history:

1. [P1] Cold activation exposed only a 21.33-point accessible target despite a 176-point orange. Native UI regression failed. Added the full circular SwiftUI content shape in `2ce0c81`; the original size assertion remains intact.
2. [P2] Toolbar circles were cramped compared with the reference. Increased their gap to 8 points in `2ce0c81`.

Second pass: CI 34021395566 passed all 51 unit tests and 17 UI tests. Same-state comparisons are `/tmp/verse-idle-reference-comparison-final.png` and `/tmp/verse-recording-reference-comparison-final.png`, with captures under `/tmp/verse-voice-evidence-34021395566/evidence/verse-smoke/`. The 176-point cold target and 8-point toolbar gap now pass. Light/dark artwork and backgrounds remain clean.

3. [P2] The second capture exposed low contrast in the disabled processing spinner. Its system-resolved colour was too close to the orange button. Added an explicit [native activity-indicator colour transformer](https://developer.apple.com/documentation/uikit/uibuttonconfiguration/activityindicatorcolortransformer) plus a regression test. This last change awaits native verification and another processing capture.

Checklist: inspect the revised same-state comparisons, require all native tests to pass, then distribute internally. Actual microphone handoff, host-owned dock blending and physical-device frame rate remain phone checks.
