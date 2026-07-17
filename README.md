# Verse

Verse is a private iPhone reader that prepares one finite morning edition while its operator sleeps. Nightjar collects source material on the VPS, removes duplicates, ranks against editable interests and feedback, writes 8 to 12 cited stories, then publishes one complete payload for the app to cache offline.

The repository already includes a source-verified first edition with 10 stories, so the app is useful before a VPS connection is configured.

## What is included

- Native SwiftUI app with Articles, Calendar, Places, Library, Topics, and Settings
- Offline SwiftData cache for editions, saved state, feedback, Markdown preferences, and queued writes
- Configurable VPS URL and a device secret stored in the iOS Keychain
- SQLite migrations and a repeatable first-edition seed
- Private HTTP API for editions, lossless Markdown preferences, feedback, and deep dives
- Fresh, isolated Nightjar app-server thread with web research
- Deterministic validation, materialization, and an ETL-only fallback
- Live collectors for arXiv, Ars Electronica, Google DeepMind, and Berlin.de events
- Stored research, prompt, model, result, and protocol provenance
- Locked, bounded systemd scheduling with preflight and inspectable run artifacts
- GitHub Actions checks for the Python stack and signing-free iOS build, tests, smoke launch, and screenshots

## Architecture

```text
live sources
    |
    v
Nightjar agent: preferences + feedback -> web research -> Markdown
                                                       |
                                                       v
                                        deterministic validation
                                                       |
                                                       v
                                     SQLite relations and prepared JSON
                                                       |
                                                       v
                                            SwiftData offline app
```

Markdown owns editable content. SQLite owns relations, feedback, deduplication, and job state. The read path never invokes a model, and a failed Nightjar run restores the previous good content.

The Topics screen edits `content/preferences.md` directly. The app preserves that document exactly, saves offline first, and asks the VPS to validate it before SQLite rebuilds its derived ranking index.

## Start the VPS service

The backend has no third-party Python dependencies and requires Python 3.12 or newer.

```bash
cp server/.env.example server/.env
python3 -c 'import secrets; print(secrets.token_urlsafe(32))'
```

Put the generated value in `VERSE_DEVICE_SECRET`, then bootstrap and run:

```bash
chmod 600 server/.env
scripts/bootstrap
python3 -m server
```

Fresh database and run artifacts are created with owner-only permissions. For an older checkout, tighten existing files once with `chmod 600 db/verse.sqlite` and `chmod -R go-rwx runs`.

Check it locally:

```bash
set -a
source server/.env
set +a
curl http://127.0.0.1:8787/health
curl -H "Authorization: Bearer $VERSE_DEVICE_SECRET" \
  http://127.0.0.1:8787/v1/edition/today
```

For a normal internet hostname, keep Verse bound to `127.0.0.1` and put an HTTPS reverse proxy in front of it. [server/Caddyfile.example](server/Caddyfile.example) is the smallest Caddy configuration. For Tailscale-only access, bind `VERSE_HOST` to the VPS Tailscale address and keep the bearer secret enabled.

The API refuses to start without a secret. A Tailscale-only deployment can explicitly opt out with `VERSE_ALLOW_UNAUTHENTICATED=1`, but this should never be combined with a public listener or reverse proxy.

## Install the scheduler

The checked-in timer runs Nightjar at 04:30 UTC and catches a missed run after the VPS returns.

```bash
scripts/install-systemd-user-units
systemctl --user enable --now verse-server.service verse-nightjar.timer
sudo loginctl enable-linger "$USER"
```

Inspect service state and the latest logs:

```bash
systemctl --user status verse-server.service verse-nightjar.timer
journalctl --user -u verse-server.service -u verse-nightjar.service -n 100
find runs/_nightjar -name result.json -print | sort | tail -1
```

Run the same fresh-agent path manually:

```bash
scripts/scheduled-nightjar
```

For an explicit deterministic fallback with no model or web research:

```bash
VERSE_NIGHTJAR_MODE=etl scripts/scheduled-nightjar
```

The default `VERSE_NIGHTJAR_MODE=agent` starts a fresh Codex app-server thread in a disposable copy of `content/` with a stripped environment. Run `scripts/install-nightjar-container` once on the VPS. The agent container mounts only that disposable workspace and a temporary Codex login copy, never the live repository, database, server environment, tunnel configuration, or publication path. The container is read-only outside the workspace and temporary directories, drops Linux capabilities, and is the filesystem boundary on hosts where unprivileged namespaces are disabled. Verse validates the Markdown, citations, edition size, and events, atomically swaps content, and then materializes SQLite and transport JSON. New editions are text-only; historical cover metadata and assets remain readable. The temporary login copy is deleted immediately after the agent exits. Prompt, result, assistant, and protocol artifacts stay under the ignored `runs/_nightjar` directory. `VERSE_AGENT_RUNTIME=local` is an explicit trusted-host fallback that uses `VERSE_AGENT_SANDBOX=workspace-write` but does not provide the same read boundary. Set `VERSE_AGENT_MODEL` only when a specific installed model is required.

## Run the iOS app

Open [Verse.xcodeproj](apps/ios/Verse.xcodeproj) in Xcode 16 or newer and run the `Verse` scheme on an iOS 17 or newer device or simulator. No signing is needed for Simulator.

On first launch, Verse opens the bundled edition. In Settings, add the HTTPS or Tailscale server address and the same `VERSE_DEVICE_SECRET`, save, then test the connection. Refresh occurs when the app opens, returns to the foreground, or is manually refreshed.

The project also has an XcodeGen source of truth at [project.yml](apps/ios/project.yml). The checked-in project means XcodeGen is optional.

## Private TestFlight

The manual `Private TestFlight` workflow builds `soli.verse` and uploads only to internal TestFlight. It never submits for App Store review or enables external testing.

Create the bundle ID and app record in App Store Connect, then configure:

- Repository variable `APPLE_TEAM_ID`
- Secrets `APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_API_ISSUER_ID`, and `APP_STORE_CONNECT_API_KEY_CONTENT`
- Secret `DISTRIBUTION_CERTIFICATE_BASE64` containing a base64-encoded Apple Distribution `.p12`
- Secret `DISTRIBUTION_CERTIFICATE_PASSWORD`
- Secret `PROVISIONING_PROFILE_BASE64` containing a base64-encoded App Store profile for `soli.verse`

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
- Verse has no accounts, analytics, ads, social surface, push notifications, or public publishing path.
