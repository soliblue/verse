# Keyboard presentation stability

1. Trace first attachment and size negotiation, including the embedded SwiftUI activation control. The reported flash is transient; settled screenshots alone are insufficient.
2. Keep the 260-point input area and native backdrop stable from first presentation. Preserve host-owned width, typing popups, voice controls, capture, streaming uploads and insertion guards. No backend or data changes.
3. Add first-layout and repeated-switch regressions plus transition capture. Run `make check` and native CI; inspect the resulting frames before release.
4. Commit, push and release to the existing internal TestFlight. Confirm Apple availability, then ask for real-phone verification of switching from another keyboard.

The activation hosting view previously received its frame only after first layout and both ancestors allowed overflow. It now has an initial frame, four-edge containment and clipping. The root declares its height in `loadView` and handles both fitting APIs. Width and the continuous backdrop remain system-owned.

[KeyboardKit issue 1041](https://github.com/KeyboardKit/KeyboardKit/issues/1041) reports a similar transient full-screen keyboard. It does not establish the cause on this phone. Controller-hosted switch recordings exercise our containment but do not replace real extension-switch testing.

Verification: `make check` passed all 25 backend tests; `git diff --check` passed. [CI 34026153524](https://github.com/soliblue/verse/actions/runs/34026153524) passed 55 native unit tests, 19 UI tests and the backend suite on commit `8164c38550351343f078d14764a114bf6be4e422`.

The iPhone 17 Pro / iOS 26.2 simulator fixture retained text and settled at 260 points across system → Verse → system → Verse in light/ready and dark/cold states. First-attachment tests cover 320, 402 and 440-point widths. Optional top-row key previews remain inside the clipped root.

Reviewed both cold-switch transitions from `voice-switch-controller-fixture.mov` frame by frame. Pixel checks of all 193 decoded frames after startup found no citrus above the keyboard area and no overlay in the empty host-content band. The recording is variable-rate simulator evidence, not a physical display FPS measurement. No full-screen takeover appeared in this fixture; the reported real-extension globe switch remains a phone check.

[TestFlight upload 34026756106](https://github.com/soliblue/verse/actions/runs/34026756106) shipped the verified commit as `0.3.1 (24)`. At 2026-09-06 10:17 UTC Apple reported `VALID`, `IN_BETA_TESTING` and membership in the existing `Internal` group. No backend, credentials, recordings or shared infrastructure changed.
