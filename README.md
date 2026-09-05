# Verse

A private iPhone transcription app. Record a message, share an audio file, or dictate through the Verse keyboard. Local Whisper on your VPS turns speech into text. No subscription, provider API, or user account.

## iPhone

- Record, copy, share, play back, and delete recordings.
- Import audio from Files or share audio from another app to Verse.
- Choose small, medium, or large-v3 and an optional language.
- Enter your device token once in Settings. The server address is preconfigured.
- History is cached for offline reading. Recordings that fail to upload remain on the device for retry.

To use the keyboard, add Verse in iPhone Settings → General → Keyboard → Keyboards, then enable Full Access. Activate a five-minute keyboard session in Verse before switching apps. Select Verse with the globe, tap Speak, Stop, then Insert transcript.

iOS does not let keyboard extensions access the microphone directly. The main app keeps an explicitly activated audio session alive; idle audio is discarded. No audio is saved until recording starts. Secure text fields and some apps do not allow third-party keyboards. Opening Verse directly from a keyboard depends on host support; manually switching to Verse always works.

Shared uploads continue on the server after acceptance. If iOS suspends the app or extension, reopen Verse to see the result. Completion notifications are best effort while the app can poll, not remote push notifications.

## Server

Install Python dependencies from `requirements-speech.txt` and system `ffmpeg`. Download the faster-whisper models before running the service. Set `VERSE_DEVICE_SECRET`, `VERSE_WHISPER_MODELS`, and the enabled models in your private environment. Run:

```sh
python -m speech_server
```

The server binds to localhost port 8787 behind the existing private-token HTTPS tunnel. Audio and transcripts are stored in SQLite and private files until deleted. Inference uses one worker with bounded uploads, queue length, duration, and runtime. See [the API contract](speech_server/README.md).

```sh
python3 -m unittest speech_server.test_server -v
```

GitHub CI builds the app and extensions and runs simulator tests. The manually triggered TestFlight workflow signs all three targets and uploads to the existing `soli.verse` app. Credentials remain in GitHub secrets.

## Layout

```text
apps/ios/src/Features/Transcription/   App UI and logic
apps/ios/Keyboard/                    Dictation keyboard
apps/ios/Share/                       Audio share extension
apps/ios/Shared/                      Shared Keychain bridge
speech_server/                       Queue, HTTP API, local Whisper
plans/18-verse-transcription.md       Implementation record
```

The old reader source and content are retained as history, but are not exposed by the app or new API. Nightjar and event-research timers remain disabled.

The icon was generated with image generation: a minimal purple-to-blue waveform on opaque white, with no text or baked-in corner mask. Its source asset is `apps/ios/src/Assets.xcassets/AppIcon.appiconset/AppIcon.png`.
