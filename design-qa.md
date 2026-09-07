# Compact receipt verification

final result: passed

Source visual truth: `/home/soli/.codex/generated_images/019f5649-2a8e-7f41-9ab5-56f5b5b7bbeb/exec-03162e0b-5332-4899-9733-4dd7fe27f4d2.png`. This refines the selected second concept with a transparent masthead. The board is 1705 by 923 pixels, showing cropped history and menu states, not a full-height phone.

Implementation evidence: [CI 34093239321](https://github.com/soliblue/verse/actions/runs/34093239321), source `27d4f75`, under `/tmp/verse-ci-34093239321/screens/verse-smoke/`. Native iPhone 17 Pro, iOS 26.2, 402 by 874 points at 3x; captures are 1206 by 2622 pixels. The reference and native captures were opened together. Corresponding content regions were compared without stretching the wide concept to phone proportions.

Full-view captures in `ui-tests/`:

- Scrolled history: `CD398FFB-4048-442B-A0BF-56C67F041B63.png`.
- Unified menu: `6B8C047A-7789-4445-999B-EA22F0104DAA.png`.
- Native half-sheet: `F7E84432-21BB-42F8-914C-DEC2AE85C551.png`.
- Swipe deletion: `47BBC165-841E-4CD5-98A6-109BC95B43C5.png`.
- Download and cancellation: `26A507EE-2C22-41E6-81AE-EC450C4217CA.png`.
- Regenerated language and retained versions: `6E3827F8-8213-4F68-A9E8-B04E12A41085.png`.

Findings:

1. Resolved P1, scrolled masthead: the first capture from `24cf951` allowed sharp transcript text behind the logo and system status text. Fix `27d4f75` uses an unpainted native [safeAreaBar](https://developer.apple.com/documentation/swiftui/view/safeareabar(edge:alignment:spacing:content:)) with a soft scroll-edge effect on iOS 26. Earlier iOS uses reserved, clipped content beneath the masthead. No solid toolbar background is added. The corrected capture keeps the status bar and controls legible, with a soft transition over the existing paper.
2. Focused comparison: `/tmp/verse-scroll-header-comparison.png` places the before and after top 1206 by 600 pixel regions side by side, each normalized to 402 by 200 pixels. Both use the same simulator, fixture history, and scrolled test state. The bar remains fixed and the text overlap is resolved. Scroll offsets differ slightly because the corrected bar reserves its native safe area.
3. No functional failures: 25 backend tests, 99 native unit tests, and 38 UI tests passed. One optional real-keyboard test was skipped. The first run ended at its ten-minute workflow limit after the new interaction tests had passed; the allowance is now twenty minutes, with per-test limits unchanged.
4. P3 platform differences: the native menu wraps long version labels and scrolls to additional models. The iOS 26 swipe action uses the existing app tint and circular trash control instead of the concept's red rectangle. Deletion retains the native destructive role, label, and full-swipe gesture. No unresolved P0, P1, or P2 findings remain.

Fidelity review:

- Typography: existing heavy-italic wordmark and native body/caption hierarchy retained. Two-line previews and one-line metadata are readable. Native menus can wrap longer model names rather than truncating them.
- Spacing: receipt margins are eight points; row text is inset twenty points. The half-sheet expands natively. The concept's enlarged popup is not used as literal phone geometry.
- Colors: original yellow paper, cream receipt, and green metadata retained. Menu glass reflects underlying artwork; it is not a custom flat-yellow popup. The native swipe action follows the existing app tint.
- Images: original citrus and receipt assets are reused, including the torn footer. No substitute drawings or new decorative assets.
- Content: saved versions, requested language, direct model actions, download/cancel state, swipe deletion, and selected-version list updates are present. Fixture dates, language, and durations intentionally differ from the concept. The keyboard shortcut is removed from history and remains available through the record button's context menu.

Release: [internal TestFlight workflow 34102640090](https://github.com/soliblue/verse/actions/runs/34102640090) uploaded version 0.3.1 (27) from verified source `27d4f75`. App Store Connect confirmed `VALID`, `IN_BETA_TESTING`, and membership in the `Internal` group on September 7, 2026. Physical microphone handoff and real-device frame rate are not established by these simulator fixtures. Local model downloads and inference in these UI tests use fixtures, not performance benchmarks.
