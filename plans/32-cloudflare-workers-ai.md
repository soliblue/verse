# Cloudflare Workers AI

1. Keep the Verse client API, model labels, upload streaming, queue, SQLite jobs, private recordings, retries, and notifications unchanged.
2. Select `cloudflare` or `local` with `VERSE_SPEECH_ENGINE`. In Cloudflare mode, send authenticated audio to one configurable Cloudflare-hosted model and return the existing transcript schema. Never fall back silently between providers.
3. Test configuration, response conversion, sanitized errors, real AAC input, the full backend suite, and the live private API. Preserve the database and recordings during service restart.

## Verification

Pending deployment verification.
