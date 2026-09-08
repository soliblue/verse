# Open audio in Verse

1. Register Verse as an alternate viewer for audio files through the system document-open flow. Keep the existing Share extension and its explicit Cloud consent separate. Do not claim default ownership of audio files.
2. Receive the file in the main app, dismiss existing sheets, and keep the selected engine, model, language, and writing style. Coordinate external file reads, copy into private pending storage off the main actor, and retain the copy for retry if processing cannot start. No implicit model downloads or Cloud fallback.
3. Run `make check`, native registration and import tests, and a simulator file-open UI smoke test. Commit and push, then verify the internal TestFlight build. Test actual WhatsApp menu discovery and its exported audio format on the phone; a simulator file-open test does not prove that flow.

## Verification

- `make check`: 25 backend tests passed.
- [Native CI](https://github.com/soliblue/verse/actions/runs/34281617994) passed for `35e4098`: 104 unit tests and 40 UI tests, with the optional real-keyboard test skipped.
- Inspected the cold-launch, sheet-dismissal, and model-preserving retry screenshots in `verse-ui-screens`. Missing Local models keep the audio pending without a Cloud upload.
- [Internal TestFlight release](https://github.com/soliblue/verse/actions/runs/34283498268) succeeded for `35e4098`. Apple confirmed `0.3.1 (28)` as `VALID` and `IN_BETA_TESTING` in the `Internal` group on September 8, 2026 at 22:05 UTC.
- WhatsApp action discovery and its exported audio encoding still need a real-phone test.
