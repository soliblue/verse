# GitHub and private TestFlight

## Goal

Publish the source as a public GitHub repository, configure reusable secrets without exposing values, and prepare an internal-only TestFlight workflow.

## Status

GitHub configuration complete. First push and CI verification are in progress. TestFlight remains intentionally blocked on Morrow-specific Apple records and signing assets.

## Contracts

- `server/.env` remains ignored and owner-readable only.
- Secret values move directly from local ignored files to GitHub Actions through `gh` without appearing in logs.
- The release workflow is manual and uploads only to internal TestFlight.
- No App Store review, public TestFlight group, or automatic release is configured.
- Morrow uses bundle identifier `soli.Morrow` and Apple team `Q9U8224WWM`.

## Decisions

- Reuse the App Store Connect API key already used by Cloude.
- Generate a distinct Morrow device secret instead of reusing another application secret.
- Do not copy Cloudflare credentials into Morrow until a deployment workflow consumes them.
- Require a Morrow-specific App Store provisioning profile and a matching Apple Distribution certificate before enabling TestFlight.

## Log

- 2026-07-12: Confirmed the Cloude App Store Connect key is structurally valid and can query the API.
- 2026-07-12: Confirmed App Store Connect has no bundle ID or app record for `soli.Morrow` yet.
- 2026-07-12: Created public repository `soliblue/morrow` and added it as `origin`.
- 2026-07-12: Generated a distinct Morrow device secret and uploaded it without exposing its value.
- 2026-07-12: Reused Cloude's App Store Connect key and distribution certificate password as GitHub Actions secrets.
- 2026-07-12: Added a manual internal-only TestFlight workflow and set repository variable `APPLE_TEAM_ID`.
- 2026-07-12: `DISTRIBUTION_CERTIFICATE_BASE64` and a Morrow-specific `PROVISIONING_PROFILE_BASE64` remain missing.
