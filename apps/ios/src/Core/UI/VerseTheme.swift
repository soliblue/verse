import SwiftUI
import UIKit

enum VerseTheme {
    static let background = adaptive(light: 0xFFFFFF, dark: 0x000000)
    static let surface = adaptive(light: 0xF7F7F7, dark: 0x1C1C1E)
    static let elevated = adaptive(light: 0xEDEDED, dark: 0x2C2C2E)
    static let foreground = adaptive(light: 0x000000, dark: 0xFFFFFF)
    static let accent = Color(red: 118 / 255, green: 103 / 255, blue: 245 / 255)
    static let secondary = foreground.opacity(VerseTokens.Opacity.l)
    static let border = foreground.opacity(VerseTokens.Opacity.s)

    static let paper = background
    static let ink = foreground
    static let secondaryInk = secondary
    static let amber = accent
    static let blue = accent

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(
            uiColor: UIColor { traits in
                let value = traits.userInterfaceStyle == .dark ? dark : light
                return UIColor(
                    red: CGFloat((value >> 16) & 0xFF) / 255,
                    green: CGFloat((value >> 8) & 0xFF) / 255,
                    blue: CGFloat(value & 0xFF) / 255,
                    alpha: 1
                )
            }
        )
    }
}
