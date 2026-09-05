#if DEBUG
import SwiftUI
import UIKit

struct KeyboardPreviewScreen: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        KeyboardFixtureController()
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {}
}

private final class KeyboardFixtureController: UIViewController {
    private let field = KeyboardFixtureTextView()
    private let arguments = ProcessInfo.processInfo.arguments
    private var keyboard: KeyboardViewController?
    private var waveformTimer: Timer?
    private var popupTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        let system = arguments.contains("--system-keyboard-ui-testing")
        let dark = arguments.contains("--keyboard-dark-ui-testing")
        overrideUserInterfaceStyle = dark ? .dark : .light
        view.backgroundColor = .systemBackground
        let title = UILabel()
        title.text = arguments.contains("--keyboard-wave-ui-testing") ? "Synthetic waveform · 10 Hz levels" : (system ? "iOS keyboard reference" : "Verse keyboard fixture")
        title.font = .systemFont(ofSize: 17, weight: .medium)
        title.textColor = .secondaryLabel
        title.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(title)
        field.accessibilityIdentifier = "keyboard-preview-text"
        field.accessibilityLabel = "Keyboard test field"
        field.font = .systemFont(ofSize: 20)
        field.keyboardAppearance = dark ? .dark : .light
        field.backgroundColor = .secondarySystemBackground
        field.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        field.layer.cornerRadius = 18
        field.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(field)
        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            title.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            field.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            field.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            field.heightAnchor.constraint(equalToConstant: 100),
            field.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -16)
        ])
        if !system {
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
            field.spellCheckingType = .no
            let controller = KeyboardViewController()
            controller.isPreview = true
            controller.previewsColdStart = arguments.contains("--keyboard-cold-ui-testing")
            controller.previewTextInput = { [weak field] text in field?.insertText(text) }
            controller.previewDeleteBackward = { [weak field] in field?.deleteBackward() }
            field.fixtureKeyboard = controller
            keyboard = controller
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        field.becomeFirstResponder()
        if arguments.contains("--keyboard-wave-ui-testing") {
            let start = ProcessInfo.processInfo.systemUptime
            let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
                let time = ProcessInfo.processInfo.systemUptime - start
                let envelope = 0.5 + 0.5 * sin(time * 2.4)
                let detail = 0.65 + 0.35 * sin(time * 13.7)
                self?.keyboard?.previewWaveform(level: envelope * detail)
            }
            RunLoop.main.add(timer, forMode: .common)
            waveformTimer = timer
        }
        if arguments.contains("--keyboard-popup-ui-testing") {
            var attempts = 0
            let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] timer in
                attempts += 1
                if attempts >= 40 { timer.invalidate() }
                guard let root = self?.keyboard?.view, root.window != nil,
                      let typing = self?.descendant(in: root, matching: { $0 is KeyboardTypingView }) as? KeyboardTypingView,
                      let key = self?.descendant(in: typing, matching: { $0.accessibilityIdentifier == "keyboard-key-q" }),
                      !typing.bounds.isEmpty, !key.bounds.isEmpty else { return }
                typing.beginTouch(id: -1, at: key.convert(CGPoint(x: key.bounds.midX, y: key.bounds.midY), to: typing), time: ProcessInfo.processInfo.systemUptime)
                timer.invalidate()
            }
            RunLoop.main.add(timer, forMode: .common)
            popupTimer = timer
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        waveformTimer?.invalidate()
        waveformTimer = nil
        popupTimer?.invalidate()
        popupTimer = nil
    }

    private func descendant(in root: UIView, matching predicate: (UIView) -> Bool) -> UIView? {
        if predicate(root) { return root }
        for view in root.subviews {
            if let match = descendant(in: view, matching: predicate) { return match }
        }
        return nil
    }
}

private final class KeyboardFixtureTextView: UITextView {
    var fixtureKeyboard: UIInputViewController?

    override var inputViewController: UIInputViewController? { fixtureKeyboard }
}
#endif
