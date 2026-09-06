# Verse

A private iPhone transcription app. Record a message, import audio, or dictate through the Verse keyboard. Whisper runs on your iPhone by default, with your VPS available as an alternative. No subscription, paid provider API, or user account.

## iPhone

- Record, copy, share, play back, and delete recordings. Open any transcript in a yellow half-sheet, switch between its versions, or transcribe the same audio with another model.
- One model list offers Local Tiny, Base, Small, Medium, Large v3, and Large v3 Turbo, plus Cloud Small, Medium, and Large v3 on your VPS. Local Medium is selected by default. Choosing an unavailable Local model starts its download; progress, cancellation, and swipe-to-remove stay in that list.
- Choose a language or let Whisper detect it. Downloaded models work offline, without a server token.
- Choose a Cloud model to use the preconfigured VPS and enter your device token.
- Recordings, original transcripts, and history remain on the iPhone for local jobs. Failed work stays available for retry with its original processing settings.
- The optional Apple Intelligence switch enables Original, Casual, Polished, and Custom writing styles using Apple's on-device text model. Original skips rewriting. Custom accepts your own instruction.

Download a model or configure Server, then allow microphone access. Add Verse in iPhone Settings → General → Keyboard → Keyboards, enable Full Access, and allow Live Activities for Verse.

Writing styles require iOS 26+, compatible hardware, and Apple Intelligence enabled with its model ready. When unavailable, the switch stays off and tapping highlights the linked setup instructions. Enable it in iPhone Settings → Apple Intelligence & Siri. Unsupported languages, unavailable models, and failed rewrites keep the original transcript. Rewriting is optional and adds processing time.

For on-device file transcription, use Import audio inside Verse. The share extension uses the VPS; when on-device mode is selected, it asks before sending anything. No audio silently falls back from local processing to the server.

Verse opens a voice-only panel by default: citrus to activate or record, a live waveform and stop control while recording, and language/model controls above. It uses the native keyboard backdrop throughout. The letter keyboard is optional under Settings → Typing keyboard. Before its first use, the switch highlights setup instructions until the actual Verse keyboard confirms Full Access. This confirmation records the last observed setup, not continuous knowledge of iOS keyboard settings.

On iOS 18 or later, add the Verse dictation control in Control Center, or assign the Toggle dictation shortcut to your Action Button. While typing in another app, trigger the control once to record and again to transcribe. Select the Verse keyboard to receive the result. Fresh dictations insert automatically once; older results offer an Insert button. Siri also supports “Dictate with Verse”.

iOS does not let keyboard extensions access the microphone directly. The audio-recording intent starts the app process without opening its interface and keeps a visible Live Activity. The microphone stays ready for 15 minutes by default, configurable to 5 or 60 minutes. Idle audio is discarded. Tap End session in the Live Activity to turn it off immediately. A manual Start keyboard session action remains available inside Verse, including on iOS 17. Secure text fields and some apps do not allow third-party keyboards. Universal direct microphone activation from the keyboard itself is not supported.

Server recordings upload compressed AAC while you speak, with final integrity checks and repeatable retries. Accepted server jobs continue independently; the keyboard polls an individual job even if iOS suspends Verse. On-device recognition runs in the app process, not the keyboard extension. If iOS terminates the app, unfinished audio remains available for retry.

Optional completion notifications contain the transcript for app recordings and imported/shared files only. Keyboard dictation never notifies. Notifications are best effort while the app can process or poll, not remote push notifications.

## Server

Install Python dependencies from `requirements-speech.txt` and system `ffmpeg`. Download the faster-whisper models before running the service. Copy `.env.example` to `.env` and configure the device secret and model directory. Run:

```sh
python -m speech_server
```

The server binds to localhost port 8787 behind the existing private-token HTTPS tunnel. Audio and transcripts are stored in SQLite and private files until deleted. Inference uses one worker with bounded uploads, queue length, duration, and runtime. See [the API contract](speech_server/README.md).

```sh
make check
```

GitHub CI builds the app and extensions and runs simulator tests. Its optional `local_model_smoke` run explicitly downloads Tiny and transcribes a public reference clip; normal CI does not download speech models. Simulator timings are not phone benchmarks. The manually triggered TestFlight workflow signs all four targets and uploads to the existing `soli.verse` app. Credentials remain in GitHub secrets.

## Layout

```text
apps/ios/src/Features/Transcription/   App UI and logic
apps/ios/Keyboard/                    Dictation keyboard
apps/ios/Share/                       Audio share extension
apps/ios/Widget/                      Live Activity and dictation control
apps/ios/Shared/                      Shared Keychain bridge
speech_server/                       Queue, HTTP API, local Whisper
scripts/                             Service template and verification tools
```

The retired reader, events, and Nightjar source have been removed. Their history remains in Git. No research automation runs.

The orange icon matches the app artwork. Its source is `apps/ios/src/Assets.xcassets/AppIcon.appiconset/AppIcon.png`. Dependency licenses are bundled in `apps/ios/src/ThirdPartyNotices.txt`.
