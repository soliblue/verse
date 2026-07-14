import SwiftUI

extension Font {
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .custom(
            weight == .regular
                ? "Fraunces-Regular"
                : weight == .bold ? "Fraunces-Bold" : "Fraunces-SemiBold",
            size: size
        )
    }

    static func reading(_ size: CGFloat, bold: Bool = false, italic: Bool = false) -> Font {
        .custom(
            bold && italic
                ? "Lora-BoldItalic"
                : bold ? "Lora-Bold" : italic ? "Lora-Italic" : "Lora-Regular",
            size: size
        )
    }

    static func utility(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func serif(_ size: CGFloat) -> Font {
        reading(size)
    }

    static func serif(_ size: CGFloat, bold: Bool, italic: Bool) -> Font {
        reading(size, bold: bold, italic: italic)
    }
}
