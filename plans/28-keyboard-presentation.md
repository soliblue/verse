# Keyboard presentation stability

1. Trace first attachment and size negotiation, including the embedded SwiftUI activation control. The reported flash is transient; settled screenshots alone are insufficient.
2. Keep the 260-point input area and native backdrop stable from first presentation. Preserve host-owned width, typing popups, voice controls, capture, streaming uploads and insertion guards. No backend or data changes.
3. Add first-layout and repeated-switch regressions plus transition capture. Run `make check` and native CI; inspect the resulting frames before release.
4. Commit, push and release to the existing internal TestFlight. Confirm Apple availability, then ask for real-phone verification of switching from another keyboard.

The activation hosting view previously received its frame only after first layout and both ancestors allowed overflow. It now has an initial frame, four-edge containment and clipping. The root declares its height in `loadView` and handles both fitting APIs. Width and the continuous backdrop remain system-owned.

[KeyboardKit issue 1041](https://github.com/KeyboardKit/KeyboardKit/issues/1041) reports a similar transient full-screen keyboard. It does not establish the cause on this phone. Controller-hosted switch recordings exercise our containment but do not replace real extension-switch testing.

Local verification: `make check` passed all 25 backend tests; `git diff --check` passed. Native verification and release are pending.
