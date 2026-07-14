import SwiftUI

struct VerseGlyph: View {
    var size: CGFloat = VerseTokens.Icon.l

    var body: some View {
        Canvas { context, canvas in
            let cell = min(canvas.width, canvas.height) / 7
            for point in [
                CGPoint(x: 3, y: 0),
                CGPoint(x: 5, y: 1),
                CGPoint(x: 5, y: 5),
                CGPoint(x: 3, y: 6),
                CGPoint(x: 1, y: 5),
                CGPoint(x: 0, y: 3),
                CGPoint(x: 1, y: 1),
                CGPoint(x: 3, y: 3),
            ] {
                context.fill(
                    Path(
                        CGRect(
                            x: point.x * cell,
                            y: point.y * cell,
                            width: cell,
                            height: cell
                        )
                    ),
                    with: .color(VerseTheme.foreground)
                )
            }
            context.fill(
                Path(CGRect(x: 6 * cell, y: 3 * cell, width: cell, height: cell)),
                with: .color(VerseTheme.accent)
            )
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
