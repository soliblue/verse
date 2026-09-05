# Keyboard refinement

Status: released in TestFlight build 21, version 0.3.0.

Preserve typing, language/model selection, recording handoff, insertion, and backend behavior.

- Replace 2.5 FPS waveform redraws with compositor-interpolated bars driven by real audio levels. Honor Reduce Motion. Do not increase Keychain polling.
- Reduce keyboard content height from 270 to 250 points, remove top padding, inset toolbar controls independently of keys.
- Keep legacy cleanup separate from the keyboard fix.

## Log

- 2026-09-05: Confirmed waveform directly redrew only on the 0.4-second bridge timer. Implemented Core Animation interpolation and compact geometry. Real-device smoothness still needs verification.
- 2026-09-05: CI 33989897491 passed native build, unit tests, and six UI tests. TestFlight run 33989971472 succeeded; Apple confirms VALID, IN_BETA_TESTING, Internal group. No claim of measured real-device FPS.
