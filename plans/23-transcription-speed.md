# Transcription speed and minimal controls

Status: implementation and verification in progress for one combined private update.

## Goal

Reduce time after stopping a recording without replacing Medium with a less reliable model or using paid/cloud transcription. Preserve the citrus design and simplify Settings.

## Contracts

- Medium is the default. Explicit model choices remain available.
- Audio remains on the phone and private VPS. No new external inference provider.
- Upload recorded bytes during speech, reconcile finalized audio headers, verify complete audio before queuing inference, retain local fallback on failure.
- Keep one whole-recording inference pass for context and accuracy.
- Reuse a bounded inference subprocess between recordings; preserve cancellation, timeout, and model switching.
- Record button is microphone, stop, or spinner without visible state text.
- Settings retains essential controls and removes instructional prose.
- Preserve unrelated legacy reader changes and pending keyboard concepts.

## Findings

- VPS has four AMD EPYC virtual CPUs and 8 GB RAM, without an identified inference GPU.
- Existing engine already uses faster-whisper INT8, four threads, VAD, and beam size 5.
- Existing worker starts a new Python process and reloads the model for every recording.
- Existing recording is already AAC at 64 kbit/s. Reducing bitrate further is not lossless.
- Apple supports streamed URLSession uploads. Recording remains owned by the app audio session, not the keyboard extension.
- WhisperKit supports local Apple Silicon inference, but actual iPhone 17 Pro latency, thermals, model memory, and keyboard-background behavior need device measurements.

## Log

- 2026-09-05: Split independent Settings and upload work; main session owns inference performance and integration. No provider keys read or external audio transfers initiated.
- 2026-09-05: User added same-citrus app icon and requested one combined update. Icon edited with built-in image generation, preserving orange/cream/yellow printed artwork, removing surrounding decorations, centering and enlarging the slice, opaque square without text or extra objects. Saved to the existing AppIcon asset as 1024x1024 RGB.
- 2026-09-05: Medium benchmark on a 5.906-second synthetic English sample: four threads model load 2.924s, inference 6.187s then 5.908s; three threads load 3.237s, inference 10.500s then 7.098s. Results had identical transcript hashes. Shared-VPS timings are variable, not a broad quality benchmark.
- 2026-09-05: Downloaded and tested local Whisper large-v3-turbo: load 2.775s, inference 6.846s then 6.692s. No speed benefit over Medium in this short CPU test, so not added to the app or made default.
- 2026-09-05: End-to-end worker test completed two actual Medium jobs in one PID: 10.100s cold and 5.747s warm. Whole-recording INT8 beam-5 decoding preserved.
- 2026-09-05: Working keyboard choice is concept 1, minimal toolbar and native-style typing keys without predictions. User can override outstanding asynchronous concept choice before release.
- 2026-09-05: User selected language code and model icon menus on the left, true input-level waveform in the center during recording, and power/waveform/stop icons on the right. This replaces the provisional concept 1 toolbar. No action words or predictions.
- 2026-09-05: Backend deployed with Medium default and four threads. Twenty backend tests passed. Synthetic end-to-end staging, idempotent finalize, actual Medium inference, and test-job deletion passed on loopback and public HTTPS. Public warm run returned after 6.825s for 5.906s of synthetic audio. Old Python urllib user agent was blocked upstream; named Verse smoke client succeeded. No authentication or tunnel changes.

## Research

- Apple streamed uploads: https://developer.apple.com/documentation/foundation/uploading-streams-of-data
- Whisper model tradeoffs: https://github.com/openai/whisper
- CPU INT8 implementation: https://github.com/SYSTRAN/faster-whisper
- On-device option: https://github.com/argmaxinc/argmax-oss-swift
- On-device inference is feasible, but no measured iPhone 17 Pro result is available here. Do not claim a phone-side speedup or silently substitute a different recognizer. This iteration retains private VPS Medium and does not use paid APIs.
