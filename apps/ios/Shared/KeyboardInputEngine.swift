#if !VERSE_WIDGET
import UIKit

@MainActor
final class KeyboardInputEngine {
    struct Touch {
        let order: Int
        let origin: KeyboardKeyLayout.Action
        let startingMode: KeyboardKeyLayout.Mode
        let startedAt: TimeInterval
        let startPoint: CGPoint
        let wasUppercase: Bool
        var key: KeyboardKeyLayout.Key?
        var uppercase: Bool
        var usedAsModifier = false
        var nextDeleteAt: TimeInterval?
        var cursorX: CGFloat?
    }

    private enum Action {
        case waiting, cancelled, delete, insert(String, TimeInterval)
    }

    private struct Input {
        let touchID: Int
        let order: Int
        var action: Action

        var isWaiting: Bool {
            if case .waiting = action { return true }
            return false
        }
    }

    var insertText: ((String) -> Void)?
    var deleteBackward: (() -> Void)?
    var adjustTextPosition: ((Int) -> Void)?
    var changed: (() -> Void)?
    private(set) var mode = KeyboardKeyLayout.Mode.letters
    private(set) var capsLocked = false
    private(set) var touches: [Int: Touch] = [:]
    private(set) var returnKey = UIReturnKeyType.default
    private var context: String? = ""
    private var autoCapitalization = UITextAutocapitalizationType.none
    private var shiftOverride: Bool?
    private var shiftOwner: Int?
    private var lastShiftAt = -Double.infinity
    private var lastSpaceAt = -Double.infinity
    private var nextOrder = 0
    private var inputs: [Input] = []

    nonisolated deinit {}

    var isUppercase: Bool {
        capsLocked || heldShift || ((shiftOverride ?? automaticUppercase) && shiftOwner == nil)
    }

    var isMovingCursor: Bool { touches.values.contains { $0.cursorX != nil } }

    var needsHoldTimer: Bool {
        touches.values.contains { $0.nextDeleteAt != nil || ($0.origin == .space && $0.cursorX == nil && $0.key?.action == .space) }
    }

    func updateContext(beforeInput: String?, autoCapitalization: UITextAutocapitalizationType, returnKey: UIReturnKeyType) {
        context = beforeInput
        self.autoCapitalization = autoCapitalization
        self.returnKey = returnKey
        changed?()
    }

    func begin(id: Int, key: KeyboardKeyLayout.Key, point: CGPoint, time: TimeInterval) {
        guard touches[id] == nil else { return }
        nextOrder += 1
        let uppercase = isUppercase
        let startingMode = mode
        touches[id] = Touch(order: nextOrder, origin: key.action, startingMode: startingMode, startedAt: time, startPoint: point, wasUppercase: uppercase, key: key, uppercase: uppercase)
        switch key.action {
        case .character, .space, .enter:
            registerInput(id: id)
            useHeldModifiers(except: id)
            if case .character(let text) = key.action, text.first?.isLetter == true,
               !capsLocked, !heldShift, shiftOwner == nil,
               shiftOverride != nil || (uppercase && autoCapitalization != .allCharacters) {
                shiftOwner = id
            }
        case .delete:
            inputs.append(Input(touchID: id, order: nextOrder, action: .delete))
            touches[id]?.nextDeleteAt = time + 0.38
            drain()
        case .mode:
            mode = mode == .letters ? .numbers : .letters
        case .shift:
            if mode != .letters { mode = mode == .numbers ? .symbols : .numbers }
        case .globe:
            break
        }
        changed?()
    }

    func move(id: Int, key: KeyboardKeyLayout.Key?, point: CGPoint, time: TimeInterval) {
        guard var touch = touches[id] else { return }
        if let cursorX = touch.cursorX {
            let offset = Int((point.x - cursorX) / 8)
            if offset != 0 {
                touch.cursorX = cursorX + CGFloat(offset) * 8
                touches[id] = touch
                adjustTextPosition?(offset)
            }
            return
        }
        let oldAction = touch.key?.action
        touch.key = key
        if touch.origin == .delete {
            touch.nextDeleteAt = key?.action == .delete ? (touch.nextDeleteAt ?? time + 0.38) : nil
        }
        if touch.origin == .shift && touch.startingMode == .letters { touch.uppercase = true }
        touches[id] = touch
        if let action = key?.action, action != oldAction {
            switch action {
            case .character, .space, .enter:
                registerInput(id: id)
                if touch.origin == .mode || touch.origin == .shift { touches[id]?.usedAsModifier = true }
            default:
                break
            }
        }
        changed?()
    }

    func end(id: Int, key: KeyboardKeyLayout.Key?, point: CGPoint, time: TimeInterval) {
        move(id: id, key: key, point: point, time: time)
        guard let touch = touches.removeValue(forKey: id) else { return }
        let action: Action
        if touch.cursorX != nil {
            action = .cancelled
        } else {
            switch key?.action {
            case .some(.character(let text)) where touch.origin != .delete:
                action = .insert(touch.uppercase ? text.uppercased() : text, time)
            case .some(.space) where touch.origin != .delete:
                action = .insert(" ", time)
            case .some(.enter) where touch.origin != .delete:
                action = .insert("\n", time)
            case .some(.delete) where touch.origin != .delete:
                action = .delete
            default:
                action = .cancelled
            }
        }
        if let index = inputs.firstIndex(where: { $0.touchID == id && $0.isWaiting }) {
            inputs[index].action = action
        } else if case .delete = action {
            inputs.append(Input(touchID: id, order: touch.order, action: action))
        }
        if touch.origin == .shift && touch.startingMode == .letters {
            if !touch.usedAsModifier && key?.action == .shift {
                shiftOwner = nil
                if capsLocked {
                    capsLocked = false
                    shiftOverride = false
                } else if time - lastShiftAt < 0.35 {
                    capsLocked = true
                    shiftOverride = nil
                } else {
                    shiftOverride = !touch.wasUppercase
                }
                lastShiftAt = time
            } else {
                lastShiftAt = -Double.infinity
            }
        }
        if touch.usedAsModifier && (touch.origin == .mode || (touch.origin == .shift && touch.startingMode != .letters)) {
            mode = touch.startingMode
        }
        if case .cancelled = action, shiftOwner == id { shiftOwner = nil }
        drain()
        changed?()
    }

    func cancel(id: Int) {
        guard let touch = touches.removeValue(forKey: id) else { return }
        if let index = inputs.firstIndex(where: { $0.touchID == id && $0.isWaiting }) { inputs[index].action = .cancelled }
        if shiftOwner == id { shiftOwner = nil }
        if touch.origin == .mode || (touch.origin == .shift && touch.startingMode != .letters) { mode = touch.startingMode }
        drain()
        changed?()
    }

    func cancelAll() {
        touches.removeAll()
        inputs.removeAll()
        shiftOwner = nil
        changed?()
    }

    func advance(to time: TimeInterval) {
        var didChange = false
        for id in touches.keys.sorted() {
            guard let touch = touches[id] else { continue }
            if let nextDeleteAt = touch.nextDeleteAt, time >= nextDeleteAt {
                inputs.append(Input(touchID: id, order: nextOrder + 1, action: .delete))
                nextOrder += 1
                touches[id]?.nextDeleteAt = time + 0.07
                didChange = true
            }
            if touch.origin == .space && touch.key?.action == .space && touch.cursorX == nil && time - touch.startedAt >= 0.4 {
                touches[id]?.cursorX = touch.startPoint.x
                if let index = inputs.firstIndex(where: { $0.touchID == id && $0.isWaiting }) { inputs[index].action = .cancelled }
                didChange = true
            }
        }
        if didChange {
            drain()
            changed?()
        }
    }

    private var heldShift: Bool {
        touches.values.contains { $0.origin == .shift && $0.startingMode == .letters && $0.key != nil }
    }

    private var automaticUppercase: Bool {
        switch autoCapitalization {
        case .none: return false
        case .allCharacters: return true
        case .words: return (context?.last).map { $0.isWhitespace } ?? true
        case .sentences:
            guard let context, !context.isEmpty else { return true }
            if context.last == "\n" { return true }
            guard context.last?.isWhitespace == true else { return false }
            let last = context.last(where: { !$0.isWhitespace })
            return last == nil || last == "." || last == "!" || last == "?"
        @unknown default: return false
        }
    }

    private func registerInput(id: Int) {
        guard !inputs.contains(where: { $0.touchID == id && $0.isWaiting }), let touch = touches[id], touch.origin != .delete else { return }
        inputs.append(Input(touchID: id, order: touch.order, action: .waiting))
        inputs.sort { $0.order < $1.order }
    }

    private func useHeldModifiers(except id: Int) {
        for otherID in touches.keys where otherID != id {
            if touches[otherID]?.origin == .shift || touches[otherID]?.origin == .mode {
                touches[otherID]?.usedAsModifier = true
            }
        }
    }

    private func drain() {
        while let input = inputs.first {
            if case .waiting = input.action { return }
            inputs.removeFirst()
            if shiftOwner == input.touchID {
                shiftOwner = nil
                if case .insert = input.action { shiftOverride = nil }
            }
            switch input.action {
            case .insert(let text, let time):
                if text == " ", time - lastSpaceAt < 0.3,
                   let context, context.last == " ",
                   let previous = context.dropLast().last, previous.isLetter || previous.isNumber {
                    self.context = String(context.dropLast()) + ". "
                    lastSpaceAt = -Double.infinity
                    deleteBackward?()
                    insertText?(". ")
                } else {
                    if context != nil { context?.append(text) }
                    lastSpaceAt = text == " " ? time : -Double.infinity
                    insertText?(text)
                }
            case .delete:
                if context?.isEmpty == false { context?.removeLast() }
                lastSpaceAt = -Double.infinity
                deleteBackward?()
            case .cancelled, .waiting:
                break
            }
        }
    }
}
#endif
