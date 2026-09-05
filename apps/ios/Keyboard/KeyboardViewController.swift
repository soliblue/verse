import UIKit

final class KeyboardViewController: UIInputViewController {
    private let status = UILabel()
    private let record = UIButton(type: .system)
    private let insert = UIButton(type: .system)
    private var timer: Timer?
    private var insertedID = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        status.font = .preferredFont(forTextStyle: .subheadline)
        status.textColor = .secondaryLabel
        status.numberOfLines = 3
        status.textAlignment = .center
        record.titleLabel?.font = .systemFont(ofSize: 22, weight: .medium)
        record.addTarget(self, action: #selector(toggleRecording), for: .touchUpInside)
        insert.setTitle("Insert transcript", for: .normal)
        insert.addTarget(self, action: #selector(insertTranscript), for: .touchUpInside)
        let next = UIButton(type: .system)
        next.setImage(UIImage(systemName: "globe"), for: .normal)
        next.accessibilityLabel = "Next keyboard"
        next.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        let delete = UIButton(type: .system)
        delete.setImage(UIImage(systemName: "delete.left"), for: .normal)
        delete.accessibilityLabel = "Delete"
        delete.addTarget(self, action: #selector(deleteCharacter), for: .touchUpInside)
        let row = UIStackView(arrangedSubviews: [next, insert, delete])
        row.distribution = .equalSpacing
        let stack = UIStackView(arrangedSubviews: [status, record, row])
        stack.axis = .vertical
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalToConstant: 240),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -24)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        timer?.invalidate()
        timer = nil
    }

    private func refresh() {
        let active = VerseBridge.sessionExpiresAt > Date().timeIntervalSince1970
        record.setTitle(VerseBridge.isRecording ? "Stop" : (active ? "Speak" : "Open Verse"), for: .normal)
        insert.isEnabled = !VerseBridge.transcriptText.isEmpty && VerseBridge.transcriptID != insertedID
        if !hasFullAccess {
            status.text = "Enable Full Access for Verse in Settings → Keyboards."
        } else if !active {
            status.text = "Open Verse and start a keyboard session, then return here."
        } else if !VerseBridge.errorText.isEmpty {
            status.text = VerseBridge.errorText
        } else {
            status.text = VerseBridge.statusText.isEmpty ? "Tap Speak, then Stop. Your words appear here." : VerseBridge.statusText
        }
    }

    @objc private func toggleRecording() {
        guard hasFullAccess else { return }
        guard VerseBridge.sessionExpiresAt > Date().timeIntervalSince1970 else {
            if let url = URL(string: "verse://keyboard") {
                extensionContext?.open(url)
            }
            return
        }
        VerseBridge.send(VerseBridge.isRecording ? "stop" : "start")
    }

    @objc private func insertTranscript() {
        let text = VerseBridge.transcriptText
        guard !text.isEmpty, VerseBridge.transcriptID != insertedID else { return }
        textDocumentProxy.insertText(text)
        insertedID = VerseBridge.transcriptID
        refresh()
    }

    @objc private func deleteCharacter() {
        textDocumentProxy.deleteBackward()
    }
}
