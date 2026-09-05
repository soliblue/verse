# Verse speech API

Private CPU transcription with faster-whisper. Install `requirements-speech.txt` and system `ffmpeg`. Download models before enabling them. Inference never downloads models and uses no paid service.

Run `python -m speech_server`. The process loads the existing project environment files. `VERSE_DEVICE_SECRET` is mandatory. Bind defaults to localhost port 8787; expose it through the existing HTTPS tunnel.

Environment:

| Variable | Default |
| --- | --- |
| `VERSE_SPEECH_DB` | `db/transcriptions.sqlite` |
| `VERSE_AUDIO_DIR` | `db/recordings` |
| `VERSE_AUDIO_STORAGE_BYTES` | `5368709120` (5 GB) |
| `VERSE_WHISPER_MODELS` | `models` |
| `VERSE_WHISPER_MODELS_ALLOWED` | `small,medium` |
| `VERSE_WHISPER_DEFAULT_MODEL` | `medium` |
| `VERSE_WHISPER_TIMEOUT` | `7200` seconds |
| `VERSE_WHISPER_THREADS` | `4` |
| `VERSE_WHISPER_IDLE_TIMEOUT` | `300` seconds |
| `VERSE_HOST` | `127.0.0.1` |
| `VERSE_PORT` | `8787` |

The models directory supports either `small/model.bin`, `medium/model.bin`, `large-v3/model.bin` directories or Hugging Face's standard cache layout. Add `large-v3` to the allowed list only after downloading it.

All endpoints require `Authorization: Bearer <device token>` except `/health`. Errors return `{"error":"message"}`. Responses must not be cached.

| Request | Response |
| --- | --- |
| `GET /health` | `{"status":"ok"}` |
| `GET /v1/config` | Available models, default model, language codes, upload and duration limits |
| `POST /v1/transcriptions?model=medium&language=auto&filename=Recording.m4a` | Raw audio body; 202 with queued job |
| `POST /v1/uploads/{id}/{index}?model=medium` | Up to 32768 raw bytes; private staging, repeatable replacement |
| `POST /v1/uploads/{id}/finish?model=medium&language=auto&filename=Recording.m4a` | JSON size, ordered chunk SHA256 hashes, full SHA256; 202 with idempotent queued job |
| `DELETE /v1/uploads/{id}` | Discard unfinished upload |
| `GET /v1/transcriptions` | `{"transcriptions":[job]}` newest first |
| `GET /v1/transcriptions/{id}` | Job |
| `GET /v1/transcriptions/{id}/audio` | Original audio bytes |
| `DELETE /v1/transcriptions/{id}` | 204; deletes recording and transcript |

Jobs contain `id`, `filename`, `state`, `model`, `language`, `detected_language`, `text`, `segments`, `duration_seconds`, `error`, `created_at`, `updated_at`. Segments contain `start`, `end`, `text`; times are seconds. Dates are UTC ISO 8601. States are `queued`, `transcribing`, `completed`, `failed`. Poll an individual job until terminal. Empty completed text means no speech was detected.

Limits: 50 MB per upload, one hour per recording, 5 GB of retained audio, 20 queued/active jobs, two concurrent uploads, 16 HTTP connections, one inference worker. Uploads preserve at least 512 MB of free disk space. Original audio is private and retained until deletion. Requests do not log tokens, filenames, or text. Pending jobs survive restart; interrupted work returns to the queue. Transcription runs in a subprocess for cancellation and time limits. Audio decoding is restricted to media containers, with no network protocols or playlists.

Tests: `python -m unittest speech_server.test_server -v`.

The inference subprocess keeps one INT8 model loaded between jobs, releasing it after five idle minutes or when the model changes. Uploads can warm the model before recording stops. Beam size 5 and whole-recording context are unchanged. Each result records `inference_seconds` without logging audio or transcript content.

The app uploads complete 32KB blocks of the existing AAC recording during speech. After closing the file it replaces any changed blocks, including rewritten m4a headers, then submits a full-file checksum. No re-encoding, split speech, or inference on incomplete audio. The full local recording is retained until the server accepts it. Stable recording IDs make finish and fallback uploads repeatable across retries. Staging is private, capped at eight unfinished recordings, counted toward the storage quota, and lazily expires after one hour. Older servers receive a normal completed-file upload instead.

Benchmark locally with `python scripts/benchmark-speech.py AUDIO MODEL_DIRECTORY --threads 4`. This prints timings and transcript hashes, never text, and sends no audio off the machine. Compare multiple representative recordings before changing the default model; a short sample is not an accuracy evaluation.
