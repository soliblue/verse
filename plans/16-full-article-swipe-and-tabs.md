# Full article swipe and tabs

Goal: Show complete articles directly in the morning reader and replace the top-left menu with native bottom navigation.

Status: Complete.

Contracts:
- The current edition opens on a complete article, without an intermediate summary card.
- Swiping left advances to the next article and swiping right returns to the previous article.
- Each article scrolls vertically when its body is longer than the screen.
- Like, dislike, refresh, and seen state remain available.
- Articles and Calendar are the only icon-only bottom tabs, with accessible names.
- Each bottom tab keeps an independent navigation stack.

Decisions:
- Use a horizontal paging scroll view around vertical article scroll views.
- Use SwiftUI's native `TabView` for bottom navigation.
- Keep semantic rounded system typography and existing story colors.

Log:
- 2026-07-26: Started reader and navigation refactor.
- 2026-07-26: Implemented shared full-article content, horizontal paging, icon-only bottom tabs, focused seen state, details access, and updated smoke tests.
- 2026-07-26: Passed 89 local tests, contract validation, Python compilation, shell syntax checks, and diff validation.
- 2026-07-26: GitHub Actions passed the release build, unit tests, UI swipe and tab tests, and simulator screenshot review.
- 2026-07-26: Removed Places, Library, and Settings from the bottom navigation, leaving only Articles and Calendar.
- 2026-07-26: Reduced article actions to direct Like and Dislike buttons and removed bookmarking and the overflow menu.
- 2026-07-26: Deleted the unused article action and details surfaces and removed the stale Settings reference from offline copy.
