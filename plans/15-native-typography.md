# Native typography

Goal: Replace custom font families and fixed text sizes with SwiftUI semantic text styles.

Status: Complete.

Contracts:
- Titles use native title or headline styles.
- Article and descriptive text uses native body styles.
- Metadata uses native caption styles.
- No bundled fonts remain.

Decisions:
- Keep the recently reduced reader headline at the semantic `title2` level.
- Use Apple's rounded system font design across the app.
- Preserve existing colors, spacing, and line limits.

Log:
- 2026-07-26: Started native typography migration.
- 2026-07-26: Replaced fixed custom typography with semantic styles, removed bundled fonts, and validated contracts, plist parsing, references, and whitespace.
- 2026-07-26: Applied the rounded system design at the app root and removed obsolete runtime font registration.
