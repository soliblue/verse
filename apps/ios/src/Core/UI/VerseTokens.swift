import CoreGraphics

enum VerseTokens {
    enum Text {
        static let hero: CGFloat = 40
        static let xxl: CGFloat = 24
        static let xl: CGFloat = 22
        static let l: CGFloat = 16
        static let m: CGFloat = 14
        static let s: CGFloat = 12
    }

    enum Icon {
        static let s: CGFloat = 14
        static let m: CGFloat = 17
        static let l: CGFloat = 21
        static let xl: CGFloat = 28
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
    }

    enum Radius {
        static let s: CGFloat = 8
        static let m: CGFloat = 14
        static let l: CGFloat = 20
    }

    enum Stroke {
        static let s: CGFloat = 1
        static let m: CGFloat = 1.5
        static let l: CGFloat = 2
    }

    enum Opacity {
        static let s: Double = 0.15
        static let m: Double = 0.4
        static let l: Double = 0.7
    }
}
