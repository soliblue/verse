# Full-bleed story cards

## Goal

Turn each Today article card into its cover image, with restrained blur and enough contrast for the title, short body, and floating actions.

## Status

Ready for private TestFlight deployment.

## Contracts

- The cover fills the entire article card and uses a soft blur.
- A dark gradient keeps the title, summary, and toolbar readable.
- Today continues to snap one article per page.
- The title and existing summary are the only persistent card copy.
- Text-only mode and stories without covers keep the paper layout.
- Story detail keeps its existing fitted cover treatment.

## Log

- 2026-07-16: Replaced the inset Today cover with a full-card media treatment and preserved the existing paging and detail contracts.
- 2026-07-17: Removed decorative screen headers and finalized the minimal navigation treatment.
