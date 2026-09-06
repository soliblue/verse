# Voice panel visual verification

final result: blocked

Source visual truth: `/home/soli/.codex/generated_images/019f5649-2a8e-7f41-9ab5-56f5b5b7bbeb/exec-3e149905-070b-4263-98e8-bda9d1ada2df.png`, Citrus (2) idle and Ribbon (3) recording. The user's latest instruction replaces the mockup's card background with one continuous native keyboard backdrop.

Implementation screenshot: not captured for this revision. XcodeBuildMCP reports `spawn xcrun ENOENT` on the Linux host. GitHub native CI requires committing/pushing; permission requested and pending. Existing build 22 screenshots are not evidence for this change.

Target viewport: 320, 402 and 440 points wide, 260-point app-owned input area plus the untouched system dock. Reference: 1448 by 1086 pixels, four concepts. Density normalization and full-view/focused comparison have not run without a native capture.

States prepared for capture: voice ready, cold activation, recording, processing, dark appearance, optional typing. Unit/UI tests cover bounds, transparent custom surfaces on a `.keyboard` input view, voice-default/typing-opt-in, and the enlarged waveform. These native tests have not run yet.

Fidelity surfaces awaiting rendered review:

1. Typography: native language/model symbols, monospaced recording time, no headings or instructional copy.
2. Spacing: 44-point toolbar targets, 16-point side margins, centered 176-point citrus, edge-to-edge waveform body.
3. Colours: native keyboard material across the input area, clear custom containers, orange controls. Confirm host-owned top/bottom areas blend in both appearances.
4. Artwork: generated slice with empty cream center, clipped to a circle. No rectangular cream background should remain visible.
5. Content: only selected language and elapsed recording time; preserved activation, recording, stop, insertion and keyboard-switch actions.

Comparison history: no rendered pass yet. No visual fidelity or on-device docking claim is made.

Next checks: run native CI, inspect combined reference/capture comparisons, fix visible mismatches, then verify the microphone handoff and system-owned dock on a real phone. Do not distribute as visually verified before these checks.
