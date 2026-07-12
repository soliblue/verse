# Morrow

Morrow is a private iPhone reader that prepares one finite morning edition while its operator sleeps. Nightjar collects source material on the VPS, removes duplicates, ranks against editable interests and feedback, writes 8 to 12 cited stories, then publishes one complete payload for the app to cache offline.

The repository already includes a source-verified first edition with 10 stories, so the app is useful before a VPS connection is configured.

## What is included

- Native SwiftUI app with Today, Library, Topics, and Settings
- Offline SwiftData cache for editions, saved state, feedback, topics, and queued writes
- Configurable VPS URL and a device secret stored in the iOS Keychain
- SQLite migrations and a repeatable first-edition seed
- Private HTTP API for editions, topics, feedback, and deep dives
- Resumable Nightjar stages for collection, normalization, deduplication, ranking, enrichment, and publishing
- Live collectors for arXiv, Ars Electronica, Google DeepMind, and Berlin.de events
- Optional local `codex exec` enrichment with stored prompt and model provenance
- Locked, bounded systemd scheduling with preflight and inspectable run artifacts
- GitHub Actions checks for the Python stack and signing-free iOS build, tests, smoke launch, and screenshots

## Architecture

```text
live sources
    |
    v
Nightjar: collect -> normalize -> deduplicate -> rank -> enrich -> validate
    |                                                           |
    |                                                           v
feedback + topics ------------------------------------------> SQLite
                                                                |
                                                                v
                                                      prepared JSON API
                                                                |
                                                                v
                                                    SwiftData offline app
```

SQLite is the source of truth. The read path never invokes a model. A nightly failure leaves the previous good edition current.

## Start the VPS service

The backend has no third-party Python dependencies and requires Python 3.12 or newer.

```bash
cp server/.env.example server/.env
python3 -c 'import secrets; print(secrets.token_urlsafe(32))'
```

Put the generated value in `MORROW_DEVICE_SECRET`, then bootstrap and run:

```bash
chmod 600 server/.env
scripts/bootstrap
python3 -m server
```

Fresh database and run artifacts are created with owner-only permissions. For an older checkout, tighten existing files once with `chmod 600 db/morrow.sqlite` and `chmod -R go-rwx runs`.

Check it locally:

```bash
set -a
source server/.env
set +a
curl http://127.0.0.1:8787/health
curl -H "Authorization: Bearer $MORROW_DEVICE_SECRET" \
  http://127.0.0.1:8787/v1/edition/today
```

For a normal internet hostname, keep Morrow bound to `127.0.0.1` and put an HTTPS reverse proxy in front of it. [server/Caddyfile.example](server/Caddyfile.example) is the smallest Caddy configuration. For Tailscale-only access, bind `MORROW_HOST` to the VPS Tailscale address and keep the bearer secret enabled.

The API refuses to start without a secret. A Tailscale-only deployment can explicitly opt out with `MORROW_ALLOW_UNAUTHENTICATED=1`, but this should never be combined with a public listener or reverse proxy.

## Install the scheduler

The checked-in timer runs Nightjar at 04:30 UTC and catches a missed run after the VPS returns.

```bash
scripts/install-systemd-user-units
systemctl --user enable --now morrow-server.service morrow-nightjar.timer
sudo loginctl enable-linger "$USER"
```

Inspect service state and the latest logs:

```bash
systemctl --user status morrow-server.service morrow-nightjar.timer
journalctl --user -u morrow-server.service -u morrow-nightjar.service -n 100
find runs/_nightjar -name result.json -print | sort | tail -1
```

Run an edition manually without model enrichment:

```bash
python3 -m etl nightly --date "$(date -u +%F)"
```

Run the normal agent-enriched path:

```bash
python3 -m etl nightly --date "$(date -u +%F)" --agent
```

`MORROW_AGENT_COMMAND` can replace the default `codex exec` boundary. It must write one JSON response to the `{output}` placeholder. Prompt versions live in [prompts](prompts), and model protocol artifacts live under the ignored `runs` directory.

## Run the iOS app

Open [Morrow.xcodeproj](apps/ios/Morrow.xcodeproj) in Xcode 16 or newer and run the `Morrow` scheme on an iOS 17 or newer device or simulator. No signing is needed for Simulator.

On first launch, Morrow opens the bundled edition. In Settings, add the HTTPS or Tailscale server address and the same `MORROW_DEVICE_SECRET`, save, then test the connection. Refresh occurs when the app opens, returns to the foreground, or is manually refreshed.

The project also has an XcodeGen source of truth at [project.yml](apps/ios/project.yml). The checked-in project means XcodeGen is optional.

## Private TestFlight

The manual `Private TestFlight` workflow builds `soli.Morrow` and uploads only to internal TestFlight. It never submits for App Store review or enables external testing.

Create the bundle ID and app record in App Store Connect, then configure:

- Repository variable `APPLE_TEAM_ID`
- Secrets `APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_API_ISSUER_ID`, and `APP_STORE_CONNECT_API_KEY_CONTENT`
- Secret `DISTRIBUTION_CERTIFICATE_BASE64` containing a base64-encoded Apple Distribution `.p12`
- Secret `DISTRIBUTION_CERTIFICATE_PASSWORD`
- Secret `PROVISIONING_PROFILE_BASE64` containing a base64-encoded App Store profile for `soli.Morrow`

Run the workflow manually after all signing inputs exist. The workflow validates its configuration before importing credentials and deletes temporary signing material afterward.

## Feedback and deep dives

- Bookmark and seen state are usable offline.
- More like this, less like this, and too basic influence later ranking.
- Offline writes stay in a SwiftData outbox and retry after connectivity returns.
- A deep-dive request is queued for the next agent-enabled Nightjar run.
- Deep-dive citations are restricted to evidence already stored with the story.

## Development checks

```bash
make check
```

The Python suite covers migrations, atomic publishing, auth, API errors, persistence, live-source parsing, idempotent stages, failure recovery, and citation provenance. The iOS targets include fixture, request-contract, offline persistence, and UI smoke tests. GitHub Actions performs the native simulator checks that are unavailable on a Linux VPS.

## Secrets and distribution

- Never commit `server/.env`, a device secret, signing material, or generated databases.
- Keep the API private behind HTTPS or Tailscale even when bearer auth is enabled.
- GitHub Actions builds without signing. Add private TestFlight or ad-hoc signing only when credentials are available.
- Morrow has no accounts, analytics, ads, social surface, push notifications, or public publishing path.
