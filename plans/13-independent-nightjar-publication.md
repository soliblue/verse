# Independent Nightjar publication

## Goal

Keep the nightly pipeline small and prevent one research product from blocking the other.

## Status

Complete.

## Contracts

- Articles and Events use separate workspaces, validation, publication, and result files.
- The daily command attempts both jobs and reports failure if either fails.
- `content/places.md` is an operator-owned, read-only watchlist.
- Events at other venues carry their venue facts in their own Markdown frontmatter.
- Failed Events work never discards a valid Articles edition, and vice versa.

## Decisions

- Reuse the existing scoped runner twice instead of adding another orchestrator or database.
- Keep one global lock around each atomic publication.
- Keep canonical watched places separate from event-local venue facts.

## Log

- 2026-07-19: Traced missing editions to a combined workspace rejected by an invalid Events place state.
- 2026-07-19: Began splitting the default daily run into independent Articles and Events transactions.
- 2026-07-19: Recovered and validated the July 18 and July 19 article editions without copying failed Events output.
- 2026-07-19: Passed 88 tests and contracts, materialized four editions, and verified the live API serves July 19.
