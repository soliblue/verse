# Direct sharing

1. Retire the server-only share extension. Use the native audio/video document opening route to launch Verse and immediately transcribe with the selected engine, model, language, and writing style. No Verse confirmation sheet, implicit model download, or server fallback.
2. Preserve private pending audio and retry settings. Ask for iOS notification permission on the first valid import, respect an explicit notification opt-out, and use existing completion notifications/history. Keep the existing bounded background task; interrupted work remains available for retry.
3. Run `make check`, native unit/UI tests and screenshot review. Push and release the verified source to the existing internal TestFlight, then check Apple processing and internal beta availability. Source-app menu discovery and background execution remain real-phone checks.
