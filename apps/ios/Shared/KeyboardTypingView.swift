#if !VERSE_WIDGET
import UIKit

final class KeyboardTypingView: UIView {
    let globeButton = UIButton(type: .custom)
    var insertText: ((String) -> Void)?
    var deleteBackward: (() -> Void)?
    var adjustTextPosition: ((Int) -> Void)?
    private let input = KeyboardInputEngine()
    private var keys: [UIButton] = []
    private var layout: [KeyboardKeyLayout.Key] = []
    private var layoutMode = KeyboardKeyLayout.Mode.letters
    private var layoutSize = CGSize.zero
    private var dark = false
    private var showsGlobe = true
    private var appearance = ""
    private var pressedSlots = Set<Int>()
    private var nativeTouchIDs: [ObjectIdentifier: Int] = [:]
    private var nextTouchID = 0
    private var holdTimer: Timer?
    private var popups: [Int: KeyboardKeyPopup] = [:]
    private var popupRemovals: [Int: DispatchWorkItem] = [:]

    var visiblePopupTexts: [String] { popups.values.map(\.text).sorted() }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        isExclusiveTouch = false
        clipsToBounds = false
        for slot in 0..<34 {
            let key = slot == 31 ? globeButton : UIButton(type: .custom)
            key.isExclusiveTouch = false
            key.accessibilityTraits.insert(.keyboardKey)
            key.layer.cornerRadius = 6
            key.layer.shadowColor = UIColor.black.cgColor
            key.layer.shadowOffset = CGSize(width: 0, height: 1)
            key.layer.shadowRadius = 0
            key.addAction(UIAction { [weak self] _ in self?.activate(slot: slot) }, for: .touchUpInside)
            addSubview(key)
            keys.append(key)
        }
        input.insertText = { [weak self] text in self?.insertText?(text) }
        input.deleteBackward = { [weak self] in self?.deleteBackward?() }
        input.adjustTextPosition = { [weak self] offset in self?.adjustTextPosition?(offset) }
        input.changed = { [weak self] in self?.refresh() }
        refresh()
    }

    required init?(coder: NSCoder) { return nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        refresh()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            input.cancelAll()
            nativeTouchIDs.removeAll()
            for id in Array(popups.keys) { removePopup(id: id) }
        }
    }

    func updateAppearance(dark: Bool) {
        guard self.dark != dark else { return }
        self.dark = dark
        refresh()
    }

    func setGlobeVisible(_ visible: Bool) {
        guard showsGlobe != visible else { return }
        showsGlobe = visible
        layoutSize = .zero
        refresh()
    }

    func updateContext(beforeInput: String?, autoCapitalization: UITextAutocapitalizationType, returnKey: UIReturnKeyType) {
        input.updateContext(beforeInput: beforeInput, autoCapitalization: autoCapitalization, returnKey: returnKey)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isUserInteractionEnabled, !isHidden, alpha > 0.01, bounds.contains(point) else { return nil }
        if showsGlobe, globeButton.frame.contains(point) { return globeButton }
        return self
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches.sorted(by: { $0.timestamp < $1.timestamp }) {
            nextTouchID += 1
            nativeTouchIDs[ObjectIdentifier(touch)] = nextTouchID
            beginTouch(id: nextTouchID, at: touch.location(in: self), time: touch.timestamp)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let id = nativeTouchIDs[ObjectIdentifier(touch)] else { continue }
            moveTouch(id: id, at: touch.location(in: self), time: touch.timestamp)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let id = nativeTouchIDs.removeValue(forKey: ObjectIdentifier(touch)) else { continue }
            endTouch(id: id, at: touch.location(in: self), time: touch.timestamp)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let id = nativeTouchIDs.removeValue(forKey: ObjectIdentifier(touch)) else { continue }
            cancelTouch(id: id)
        }
    }

    func beginTouch(id: Int, at point: CGPoint, time: TimeInterval) {
        refresh()
        guard bounds.contains(point), let key = key(at: point, tracking: nil), key.action != .globe else { return }
        removePopup(id: id)
        input.begin(id: id, key: key, point: point, time: time)
    }

    func moveTouch(id: Int, at point: CGPoint, time: TimeInterval) {
        input.move(id: id, key: key(at: point, tracking: id), point: point, time: time)
    }

    func endTouch(id: Int, at point: CGPoint, time: TimeInterval) {
        input.end(id: id, key: key(at: point, tracking: id), point: point, time: time)
        if popups[id] != nil {
            let removal = DispatchWorkItem { [weak self] in self?.removePopup(id: id) }
            popupRemovals[id] = removal
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06, execute: removal)
        }
    }

    func cancelTouch(id: Int) {
        input.cancel(id: id)
        removePopup(id: id)
    }

    func advanceTime(to time: TimeInterval) { input.advance(to: time) }

    private func key(at point: CGPoint, tracking id: Int?) -> KeyboardKeyLayout.Key? {
        guard bounds.insetBy(dx: -10, dy: -8).contains(point) else { return nil }
        if let id, let current = input.touches[id]?.key,
           current.frame.insetBy(dx: -3, dy: -3).contains(point) {
            return current
        }
        return layout.filter { $0.action != .globe }.min {
            distance(from: point, to: $0.frame) < distance(from: point, to: $1.frame)
        }
    }

    private func distance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let x = max(max(rect.minX - point.x, 0), point.x - rect.maxX)
        let y = max(max(rect.minY - point.y, 0), point.y - rect.maxY)
        return x * x + y * y
    }

    private func activate(slot: Int) {
        guard let key = layout.first(where: { $0.slot == slot }), key.action != .globe else { return }
        nextTouchID += 1
        let point = CGPoint(x: key.frame.midX, y: key.frame.midY)
        let time = ProcessInfo.processInfo.systemUptime
        beginTouch(id: nextTouchID, at: point, time: time)
        endTouch(id: nextTouchID, at: point, time: time)
    }

    private func refresh() {
        if layoutSize != bounds.size || layoutMode != input.mode {
            layout = KeyboardKeyLayout.keys(in: bounds, mode: input.mode, globe: showsGlobe)
            layoutSize = bounds.size
            layoutMode = input.mode
            let visible = Set(layout.map(\.slot))
            for (slot, key) in keys.enumerated() { key.isHidden = !visible.contains(slot) }
            for key in layout { keys[key.slot].frame = key.frame }
            appearance = ""
        }
        let newAppearance = "\(input.mode)-\(input.isUppercase)-\(input.capsLocked)-\(input.returnKey.rawValue)-\(input.isMovingCursor)-\(dark)"
        let appearanceChanged = appearance != newAppearance
        if appearanceChanged {
            appearance = newAppearance
            for key in layout { configure(keys[key.slot], action: key.action) }
        }
        let pressed = Set(input.touches.values.compactMap { $0.cursorX == nil ? $0.key?.slot : nil })
        for key in layout where appearanceChanged || pressed.contains(key.slot) != pressedSlots.contains(key.slot) {
            style(keys[key.slot], action: key.action, pressed: pressed.contains(key.slot))
        }
        pressedSlots = pressed
        for (id, touch) in input.touches {
            guard case .some(.character(let text)) = touch.key?.action, let key = touch.key else {
                removePopup(id: id)
                continue
            }
            let popup = popups[id] ?? KeyboardKeyPopup()
            if popups[id] == nil {
                popups[id] = popup
                addSubview(popup)
            }
            popup.update(text: touch.uppercase ? text.uppercased() : text, keyFrame: key.frame, keyboardWidth: bounds.width, dark: dark)
        }
        if input.needsHoldTimer && holdTimer == nil {
            let timer = Timer(timeInterval: 0.035, repeats: true) { [weak self] _ in self?.advanceTime(to: ProcessInfo.processInfo.systemUptime) }
            RunLoop.main.add(timer, forMode: .common)
            holdTimer = timer
        } else if !input.needsHoldTimer {
            holdTimer?.invalidate()
            holdTimer = nil
        }
    }

    private func configure(_ key: UIButton, action: KeyboardKeyLayout.Action) {
        let title: String
        let label: String
        let symbol: String?
        switch action {
        case .character(let text):
            title = input.isUppercase ? text.uppercased() : text
            label = title
            symbol = nil
            key.accessibilityIdentifier = "keyboard-key-\(text)"
        case .shift:
            title = input.mode == .letters ? "" : (input.mode == .numbers ? "#+=" : "123")
            label = input.mode == .letters ? "Shift" : "More symbols"
            symbol = input.mode == .letters ? (input.capsLocked ? "capslock.fill" : (input.isUppercase ? "shift.fill" : "shift")) : nil
            key.accessibilityIdentifier = "keyboard-key-shift"
            key.accessibilityValue = input.capsLocked ? "Caps Lock" : (input.isUppercase ? "On" : "Off")
        case .delete:
            title = ""
            label = "Delete"
            symbol = "delete.left"
            key.accessibilityIdentifier = "keyboard-key-delete"
        case .mode:
            title = input.mode == .letters ? "123" : "ABC"
            label = input.mode == .letters ? "Numbers" : "Letters"
            symbol = nil
            key.accessibilityIdentifier = "keyboard-key-mode"
        case .globe:
            title = ""
            label = "Next keyboard"
            symbol = "globe"
            key.accessibilityIdentifier = "keyboard-key-globe"
        case .space:
            title = "space"
            label = "Space"
            symbol = nil
            key.accessibilityIdentifier = "keyboard-key-space"
        case .enter:
            title = returnTitle
            label = "Return"
            symbol = title.isEmpty ? "return" : nil
            key.accessibilityIdentifier = "keyboard-key-return"
        }
        key.setTitle(title, for: .normal)
        key.setImage(symbol.flatMap { UIImage(systemName: $0, withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)) }, for: .normal)
        key.titleLabel?.font = .systemFont(ofSize: action.isCharacter ? 26 : 16)
        key.accessibilityLabel = label
        key.titleLabel?.alpha = input.isMovingCursor ? 0 : 1
        key.imageView?.alpha = input.isMovingCursor ? 0 : 1
    }

    private func style(_ key: UIButton, action: KeyboardKeyLayout.Action, pressed: Bool) {
        let special = !action.isCharacter && action != .space
        let activeShift = action == .shift && input.mode == .letters && input.isUppercase
        let actionReturn = action == .enter && !returnTitle.isEmpty
        let background: UIColor
        let foreground: UIColor
        if actionReturn {
            background = pressed ? UIColor.systemBlue.withAlphaComponent(0.75) : .systemBlue
            foreground = .white
        } else if activeShift {
            background = .white
            foreground = .black
        } else {
            background = dark
                ? UIColor(white: pressed ? 0.42 : (special ? 0.20 : 0.29), alpha: 1)
                : (pressed ? UIColor(white: 0.88, alpha: 1) : (special ? UIColor(red: 0.68, green: 0.70, blue: 0.74, alpha: 1) : .white))
            foreground = dark ? .white : .black
        }
        if key.backgroundColor != background { key.backgroundColor = background }
        key.tintColor = foreground
        key.setTitleColor(foreground, for: .normal)
        key.layer.shadowOpacity = dark ? 0 : 0.2
    }

    private var returnTitle: String {
        switch input.returnKey {
        case .go: return "go"
        case .google, .yahoo, .search: return "search"
        case .join: return "join"
        case .next: return "next"
        case .route: return "route"
        case .send: return "send"
        case .done: return "done"
        case .emergencyCall: return "call"
        case .continue: return "continue"
        default: return ""
        }
    }

    private func removePopup(id: Int) {
        popupRemovals.removeValue(forKey: id)?.cancel()
        popups.removeValue(forKey: id)?.removeFromSuperview()
    }
}

private extension KeyboardKeyLayout.Action {
    var isCharacter: Bool {
        if case .character = self { return true }
        return false
    }
}
#endif
