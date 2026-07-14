import SwiftUI
import UIKit

enum VerseTheme {
    static let paper = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.06, green: 0.07, blue: 0.08, alpha: 1)
                : UIColor(red: 0.97, green: 0.96, blue: 0.92, alpha: 1)
        }
    )
    static let surface = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.11, green: 0.12, blue: 0.13, alpha: 1)
                : UIColor(red: 1, green: 0.995, blue: 0.98, alpha: 1)
        }
    )
    static let ink = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.94, green: 0.92, blue: 0.86, alpha: 1)
                : UIColor(red: 0.08, green: 0.12, blue: 0.16, alpha: 1)
        }
    )
    static let secondaryInk = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.66, green: 0.67, blue: 0.65, alpha: 1)
                : UIColor(red: 0.36, green: 0.39, blue: 0.40, alpha: 1)
        }
    )
    static let amber = Color(red: 0.82, green: 0.43, blue: 0.12)
    static let blue = Color(red: 0.20, green: 0.37, blue: 0.46)
}
