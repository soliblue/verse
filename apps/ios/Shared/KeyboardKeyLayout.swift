#if !VERSE_WIDGET
import UIKit

enum KeyboardKeyLayout {
    enum Mode: Equatable { case letters, numbers, symbols }

    enum Action: Equatable {
        case character(String), shift, delete, mode, globe, space, enter
    }

    struct Key {
        let slot: Int
        let action: Action
        let frame: CGRect
    }

    static func keys(in bounds: CGRect, mode: Mode, globe: Bool) -> [Key] {
        guard bounds.width > 0, bounds.height > 0 else { return [] }
        let gap: CGFloat = 6
        let rowGap: CGFloat = 11
        let inset: CGFloat = 6.5
        let contentWidth = bounds.width - inset * 2
        let height = bounds.height / 4 - rowGap
        let width = (contentWidth - gap * 9) / 10
        let pitch = width + gap
        let rows: [[String]]
        switch mode {
        case .letters:
            rows = [Array("qwertyuiop").map(String.init), Array("asdfghjkl").map(String.init), Array("zxcvbnm").map(String.init)]
        case .numbers:
            rows = [Array("1234567890").map(String.init), ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""], [".", ",", "?", "!", "'"]]
        case .symbols:
            rows = [["[", "]", "{", "}", "#", "%", "^", "*", "+", "="], ["_", "\\", "|", "~", "<", ">", "€", "£", "¥"], [".", ",", "?", "!", "'"]]
        }
        var result: [Key] = []
        for row in 0...1 {
            let inset = (contentWidth - (CGFloat(rows[row].count) * pitch - gap)) / 2
            for (column, character) in rows[row].enumerated() {
                result.append(Key(slot: row * 10 + column, action: .character(character), frame: CGRect(x: inset + CGFloat(column) * pitch, y: CGFloat(row) * (height + rowGap), width: width, height: height)))
            }
        }
        let thirdY = 2 * (height + rowGap)
        let modifierWidth = width + 12
        result.append(Key(slot: 20, action: .shift, frame: CGRect(x: 0, y: thirdY, width: modifierWidth, height: height)))
        let thirdWidth = mode == .letters ? width : (contentWidth - modifierWidth * 2 - gap * 6) / 5
        let thirdInset = (contentWidth - (CGFloat(rows[2].count) * (thirdWidth + gap) - gap)) / 2
        for (column, character) in rows[2].enumerated() {
            result.append(Key(slot: 21 + column, action: .character(character), frame: CGRect(x: thirdInset + CGFloat(column) * (thirdWidth + gap), y: thirdY, width: thirdWidth, height: height)))
        }
        result.append(Key(slot: 29, action: .delete, frame: CGRect(x: contentWidth - modifierWidth, y: thirdY, width: modifierWidth, height: height)))
        let bottomY = 3 * (height + rowGap)
        let returnWidth = pitch * 2.5 - gap
        let modeWidth = globe ? contentWidth * 0.135 : returnWidth
        let globeWidth = globe ? contentWidth * 0.135 : 0
        let spaceX = modeWidth + gap + (globe ? globeWidth + gap : 0)
        result.append(Key(slot: 30, action: .mode, frame: CGRect(x: 0, y: bottomY, width: modeWidth, height: height)))
        if globe {
            result.append(Key(slot: 31, action: .globe, frame: CGRect(x: modeWidth + gap, y: bottomY, width: globeWidth, height: height)))
        }
        result.append(Key(slot: 32, action: .space, frame: CGRect(x: spaceX, y: bottomY, width: contentWidth - spaceX - returnWidth - gap, height: height)))
        result.append(Key(slot: 33, action: .enter, frame: CGRect(x: contentWidth - returnWidth, y: bottomY, width: returnWidth, height: height)))
        return result.map { Key(slot: $0.slot, action: $0.action, frame: $0.frame.offsetBy(dx: inset, dy: 0)) }
    }
}
#endif
