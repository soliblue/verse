# Verse rename

## Goal

Rename the product and repository to Verse with the exact iOS bundle identifier `soli.verse`.

## Status

Complete. The public repository, app, backend, operations, and GitHub configuration use Verse.

## Contracts

- The app, Xcode targets, repository, API namespace, and deployment units use Verse.
- The app bundle identifier is exactly `soli.verse`.
- Test bundle identifiers are `soli.verse.tests` and `soli.verse.uitests`.
- Existing content and the device secret value are preserved.
- No Apple Developer or App Store Connect records are created by this work.
- Historical plan log entries remain unchanged.

## Decisions

- Rename the backend environment namespace to `VERSE_` before deployment.
- Rename the SQLite default to `db/verse.sqlite` and systemd units to `verse-*`.
- Keep Nightjar as the overnight worker name.
- Keep the local workspace directory unchanged because it is owned by the active Codex environment.

## Log

- 2026-07-14: Audited all product identity references and started the full rename.
- 2026-07-14: Renamed the Xcode project, targets, Swift types, backend namespace, database default, and systemd units.
- 2026-07-14: Migrated the ignored local environment and GitHub device secret to `VERSE_DEVICE_SECRET` without changing its value.
- 2026-07-14: Renamed the public repository to `soliblue/verse`, committed as `dc7daa2`, and pushed `main`.
- 2026-07-14: Local checks passed 55 tests plus contract, project, workflow, systemd, and secret validation.
- 2026-07-14: GitHub Actions run `29325717736` passed the backend, native build, unit tests, UI tests, launch, and light and dark screenshots for `soli.verse`.
