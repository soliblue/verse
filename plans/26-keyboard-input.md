# Keyboard input fidelity

Status: in progress.

## Goal

Make fast typing reliable and approximate the current iPhone keyboard: character popups, continuous touch targets, correct row geometry, compact toolbar, and accessible controls.

## Contracts

- Preserve language/model selection, microphone handoff, live waveform, streaming uploads, and insertion guards.
- No paid SDK, telemetry, server change, or unrelated redesign.
- Keep touches independent, including overlapping fingers. Do not recreate keys during ordinary typing or shift changes.
- Verify touch cancellation, gap hits, sliding, shift/caps, delete repeat, and popups. Simulator fixtures are not proof of real-device typing feel.
- Submit privately through the existing TestFlight app after checks.

## Work

1. Input agent: independent touch routing, stable keycaps, popups, native typing conventions, deterministic tests.
2. Root: 51-point row pitch, 44-point toolbar, host keyboard material, background bridge reads, insertion safety.
3. Research agent: open-source review, background audio-meter publication, completion-path audit.
4. Evidence agent: real UIKit keyboard hosting, native reference screenshots, waveform video, UI and performance tests.
5. Root: inspect native CI results and rendered evidence, commit and push, then verify internal TestFlight availability.

## References

- [Tasty Imitation Keyboard](https://github.com/archagon/tasty-imitation-keyboard/blob/master/Keyboard/ForwardingView.swift): independent touch routing and nearest-key targeting. Its old visual dimensions and same-key cancellation are not reused.
- [KeyboardKit 9.9](https://github.com/KeyboardKit/KeyboardKit/blob/9.9.0/Sources/KeyboardKit/Callouts/CalloutContext.swift): short character-preview persistence after release.
- [KeyboardKit release notes](https://github.com/KeyboardKit/KeyboardKit/blob/main/RELEASE_NOTES.md): iOS 26 phone row pitch.
- [azooKey](https://github.com/azooKey/azooKey/blob/main/Keyboard/Display/KeyboardViewController.swift): system keyboard material and host sizing.
- [Apple ProMotion guidance](https://developer.apple.com/documentation/quartzcore/optimizing-iphone-and-ipad-apps-to-support-promotion-displays): opt in to higher refresh rates and request display-paced Core Animation while recording. System and host conditions still determine actual frame rate.
- Independent implementation. No SDK or new package dependency.

## Log

- 2026-09-05: Current keys are separate touchUpInside buttons with dead gaps; shift rebuilds the whole keyboard and can discard concurrent touches. Root controller also performs repeated synchronous Keychain reads on the main thread. Target both mechanisms, not only appearance.
- Stable keycaps now cover visual gaps and track overlapping fingers in press order. Popups appear on contact and briefly persist after release.
- Typing updates local capitalization context immediately; host changes resynchronize through UIKit callbacks without a redundant context query after every key.
- Audio metering publishes and reads real RMS on background queues at 10 Hz. Core Animation interpolates the 11 bars; unchanged layout passes no longer cancel animations.
- Poll completion writes also run off the typing thread, retaining the live job-ID check and insertion publication order.
- Insertion keeps both persistent and local transcript guards so an older bridge snapshot cannot insert twice.
- Native verification pending. Synthetic simulator animation is not evidence of microphone handoff or physical-device frame rate.
- First CI run [33992363217](https://github.com/soliblue/verse/actions/runs/33992363217) compiled all iOS targets and passed backend, RMS, insertion, and waveform tests. It exposed Swift's isolated-deinitializer crash during synchronous input-engine teardown and an unbound test input view. No TestFlight upload was started.
- Explicit nonisolated teardown fixes the engine lifetime path; the fixture now binds the controller's concrete input view through UIKit. Unit summaries are exported before UI tests finish.
- The crash stack matches [Swift issue 87316](https://github.com/swiftlang/swift/issues/87316). The regression test retains synchronous teardown rather than hiding it behind an async test.
