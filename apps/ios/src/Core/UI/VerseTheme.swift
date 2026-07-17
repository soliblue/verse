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
    static func storyBackground(for identifier: String) -> Color {
        let palette: [(UInt32, UInt32)] = [
            (0xF1D8CB, 0x3A2B26),
            (0xDED8F0, 0x302D41),
            (0xD4E5D9, 0x28382E),
            (0xD5E2ED, 0x293641),
            (0xEFE2B9, 0x3B3525),
            (0xE9D4DD, 0x3B2C34),
        ]
        let hash = identifier.utf8.reduce(UInt64(1_469_598_103_934_665_603)) {
            ($0 ^ UInt64($1)) &* 1_099_511_628_211
        }
        let colors = palette[Int(hash % UInt64(palette.count))]
        return adaptive(light: colors.0, dark: colors.1)
    }

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
