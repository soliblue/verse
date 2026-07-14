# Verse rename

## Goal

Rename the product and repository to Verse with the exact iOS bundle identifier `soli.verse`.

## Status

In progress.

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
