# GitHub and private TestFlight

## Goal

Publish the source as a public GitHub repository, configure reusable secrets without exposing values, and prepare an internal-only TestFlight workflow.

## Status

GitHub publication, secrets, and CI verification are complete. TestFlight remains intentionally blocked on Verse-specific Apple records and signing assets.

## Contracts

- `server/.env` remains ignored and owner-readable only.
- Secret values move directly from local ignored files to GitHub Actions through `gh` without appearing in logs.
- The release workflow is manual and uploads only to internal TestFlight.
- No App Store review, public TestFlight group, or automatic release is configured.
- Verse uses bundle identifier `soli.verse` and Apple team `Q9U8224WWM`.

## Decisions

- Reuse the App Store Connect API key already used by Cloude.
- Preserve the distinct device secret while renaming its environment key to `VERSE_DEVICE_SECRET`.
- Do not copy Cloudflare credentials into Verse until a deployment workflow consumes them.
- Require a Verse-specific App Store provisioning profile and a matching Apple Distribution certificate before enabling TestFlight.

## Log

- 2026-07-12: Confirmed the Cloude App Store Connect key is structurally valid and can query the API.
- 2026-07-12: Confirmed App Store Connect has no bundle ID or app record for `soli.Morrow` yet.
- 2026-07-12: Created public repository `soliblue/morrow` and added it as `origin`.
- 2026-07-12: Generated a distinct Morrow device secret and uploaded it without exposing its value.
- 2026-07-12: Reused Cloude's App Store Connect key and distribution certificate password as GitHub Actions secrets.
- 2026-07-12: Added a manual internal-only TestFlight workflow and set repository variable `APPLE_TEAM_ID`.
- 2026-07-12: `DISTRIBUTION_CERTIFICATE_BASE64` and a Morrow-specific `PROVISIONING_PROFILE_BASE64` remain missing.
- 2026-07-12: The first GitHub-hosted Release build passed. Split the combined Xcode test command after simulator-clone parallelism stalled without diagnostics.
- 2026-07-12: The bounded unit run exposed an iOS 26 crash in shared `ISO8601DateFormatter` instances. Replaced them with value-type ISO 8601 parse strategies.
- 2026-07-12: Crash attachments refined the diagnosis to Swift's Xcode 26.2 isolated-deinitializer runtime bug during synchronous XCTest teardown; timestamp parsing was not on either crash stack.
- 2026-07-12: Added explicit nonisolated deinitializers to the affected main-actor dependency chain while retaining the value-type timestamp parser.
- 2026-07-12: GitHub Actions run `29198014723` passed backend checks, signing-free Release build, unit tests, UI smoke tests, and light and dark screenshot capture.
- 2026-07-14: Began renaming the product, bundle identifier, repository, and device-secret key to Verse.
