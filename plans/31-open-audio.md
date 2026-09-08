# Open audio in Verse

1. Register Verse as an alternate viewer for audio files through the system document-open flow. Keep the existing Share extension and its explicit Cloud consent separate. Do not claim default ownership of audio files.
2. Receive the file in the main app, dismiss existing sheets, and keep the selected engine, model, language, and writing style. Coordinate external file reads, copy into private pending storage off the main actor, and retain the copy for retry if processing cannot start. No implicit model downloads or Cloud fallback.
3. Run `make check`, native registration and import tests, and a simulator file-open UI smoke test. Commit and push, then verify the internal TestFlight build. Test actual WhatsApp menu discovery and its exported audio format on the phone; a simulator file-open test does not prove that flow.

## Verification

Pending native CI and internal TestFlight availability.
