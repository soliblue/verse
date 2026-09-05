#if !VERSE_WIDGET
import UIKit

final class KeyboardTypingView: UIView {
    let globeButton = UIButton(type: .system)
    var insertText: ((String) -> Void)?
    var deleteBackward: (() -> Void)?
    private let rows = UIStackView()
    private var shifted = false
    private var capsLocked = false
    private var numbers = false
    private var symbols = false
    private var lastShiftTap = Date.distantPast
    private var deleteTimer: Timer?
    private var dark = false
    private var keys: [UIButton] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        rows.axis = .vertical
        rows.spacing = 7
        rows.distribution = .fillEqually
        rows.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rows)
        NSLayoutConstraint.activate([
            rows.leadingAnchor.constraint(equalTo: leadingAnchor),
            rows.trailingAnchor.constraint(equalTo: trailingAnchor),
            rows.topAnchor.constraint(equalTo: topAnchor),
            rows.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        rebuild()
    }

    required init?(coder: NSCoder) { return nil }

    func updateAppearance(dark: Bool) {
        self.dark = dark
        for key in keys { style(key) }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { stopDeleting() }
    }

    private func rebuild() {
        stopDeleting()
        for row in rows.arrangedSubviews { row.removeFromSuperview() }
        keys.removeAll()
        let letters = numbers
            ? (symbols ? ["[ ] { } # % ^ * + =", "_ \\ | ~ < > € £ ¥", ". , ? ! '"] : ["1 2 3 4 5 6 7 8 9 0", "- / : ; ( ) $ & @ \"", ". , ? ! '"])
            : ["q w e r t y u i o p", "a s d f g h j k l", "z x c v b n m"]
        for (index, letters) in letters.enumerated() {
            let row = UIStackView()
            row.spacing = 6
            row.distribution = .fillEqually
            if index == 2 {
                let title = numbers ? (symbols ? "123" : "#+=") : ""
                let shift = button(title, label: numbers ? "More symbols" : "Shift") { [weak self] in self?.shift() }
                if !numbers {
                    shift.setImage(UIImage(systemName: capsLocked ? "capslock.fill" : (shifted ? "shift.fill" : "shift")), for: .normal)
                    shift.accessibilityValue = capsLocked ? "Caps Lock" : (shifted ? "On" : "Off")
                }
                shift.tag = 1
                style(shift)
                row.addArrangedSubview(shift)
            }
            for character in letters.split(separator: " ").map(String.init) {
                let text = shifted && !numbers ? character.uppercased() : character
                row.addArrangedSubview(button(text, label: text) { [weak self] in
                    self?.insertText?(text)
                    if self?.shifted == true && self?.capsLocked == false {
                        self?.shifted = false
                        self?.rebuild()
                    }
                })
            }
            if index == 2 {
                let delete = button("", label: "Delete") { [weak self] in self?.deleteBackward?() }
                delete.tag = 1
                delete.setImage(UIImage(systemName: "delete.left"), for: .normal)
                style(delete)
                let hold = UILongPressGestureRecognizer(target: self, action: #selector(repeatDelete(_:)))
                hold.minimumPressDuration = 0.35
                delete.addGestureRecognizer(hold)
                row.addArrangedSubview(delete)
            }
            if index == 1 {
                let inset = UIView()
                inset.addSubview(row)
                row.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    row.leadingAnchor.constraint(equalTo: inset.leadingAnchor, constant: 17),
                    row.trailingAnchor.constraint(equalTo: inset.trailingAnchor, constant: -17),
                    row.topAnchor.constraint(equalTo: inset.topAnchor),
                    row.bottomAnchor.constraint(equalTo: inset.bottomAnchor)
                ])
                rows.addArrangedSubview(inset)
            } else { rows.addArrangedSubview(row) }
        }
        let mode = button(numbers ? "ABC" : "123", label: numbers ? "Letters" : "Numbers") { [weak self] in
            self?.numbers.toggle()
            self?.symbols = false
            self?.rebuild()
        }
        mode.tag = 1
        style(mode)
        globeButton.setImage(UIImage(systemName: "globe"), for: .normal)
        globeButton.accessibilityLabel = "Next keyboard"
        globeButton.tag = 1
        keys.append(globeButton)
        style(globeButton)
        let space = button("space", label: "Space") { [weak self] in self?.insertText?(" ") }
        space.titleLabel?.font = .systemFont(ofSize: 17)
        let enter = button("", label: "Return") { [weak self] in self?.insertText?("\n") }
        enter.tag = 1
        enter.setImage(UIImage(systemName: "return"), for: .normal)
        style(enter)
        let bottom = UIStackView(arrangedSubviews: [mode, globeButton, space, enter])
        bottom.spacing = 6
        let globeWidth = globeButton.widthAnchor.constraint(equalTo: bottom.widthAnchor, multiplier: 0.13)
        globeWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            mode.widthAnchor.constraint(equalTo: bottom.widthAnchor, multiplier: 0.13),
            globeWidth,
            enter.widthAnchor.constraint(equalTo: bottom.widthAnchor, multiplier: 0.22)
        ])
        rows.addArrangedSubview(bottom)
    }

    private func button(_ title: String, label: String, action: @escaping () -> Void) -> UIButton {
        let key = UIButton(type: .system)
        key.setTitle(title, for: .normal)
        key.accessibilityLabel = label
        key.titleLabel?.font = .systemFont(ofSize: title.count > 1 ? 17 : 25)
        key.addAction(UIAction { _ in action() }, for: .touchUpInside)
        keys.append(key)
        style(key)
        return key
    }

    private func style(_ key: UIButton) {
        key.backgroundColor = dark
            ? UIColor(white: key.tag == 1 ? 0.20 : 0.27, alpha: 1)
            : (key.tag == 1 ? UIColor(red: 0.68, green: 0.70, blue: 0.73, alpha: 1) : .white)
        key.tintColor = dark ? .white : .black
        key.setTitleColor(dark ? .white : .black, for: .normal)
        key.layer.cornerRadius = 5
        key.layer.shadowColor = UIColor.black.cgColor
        key.layer.shadowOpacity = dark ? 0 : 0.18
        key.layer.shadowOffset = CGSize(width: 0, height: 1)
        key.layer.shadowRadius = 0
    }

    private func shift() {
        if numbers { symbols.toggle() }
        else {
            let doubleTap = Date().timeIntervalSince(lastShiftTap) < 0.35
            capsLocked = doubleTap && shifted
            shifted = capsLocked || !shifted
            lastShiftTap = Date()
        }
        rebuild()
    }

    @objc private func repeatDelete(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            deleteBackward?()
            deleteTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in self?.deleteBackward?() }
        } else if gesture.state != .changed { stopDeleting() }
    }

    private func stopDeleting() {
        deleteTimer?.invalidate()
        deleteTimer = nil
    }
}
#endif
