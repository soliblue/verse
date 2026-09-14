# Cloudflare Workers AI

1. Keep the Verse client API, model labels, upload streaming, queue, SQLite jobs, private recordings, retries, and notifications unchanged.
2. Select `cloudflare` or `local` with `VERSE_SPEECH_ENGINE`. In Cloudflare mode, send authenticated audio to one configurable Cloudflare-hosted model and return the existing transcript schema. Never fall back silently between providers.
3. Test configuration, response conversion, sanitized errors, real AAC input, the full backend suite, and the live private API. Preserve the database and recordings during service restart.

## Verification

- `make check`: 28 backend tests passed.
- A real 11-second AAC/m4a probe completed through `@cf/openai/whisper-large-v3-turbo` in 1.74 seconds with text, timestamps, and English detection.
- The live streamed-upload smoke completed in 2.605 seconds, returned 108 characters, and deleted its test recording.
- `verse-server.service`, `verse-tunnel.service`, and `https://verse.soli.blue/health` are healthy. Ten existing jobs and ten recording files remain, with no queued or transcribing jobs.
- GitHub CI is pending for `c2de70f`.
