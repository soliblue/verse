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
        let active = sessionIsActive
        let recording = active && VerseBridge.isRecording
        let commandPending = active && VerseBridge.commandID != VerseBridge.acknowledgedCommandID
        let processing = isProcessing
        let hasTranscript = !VerseBridge.transcriptText.isEmpty && VerseBridge.transcriptID != insertedID
        record.setTitle(!active ? "Open Verse" : (recording ? "Stop" : (processing ? "Transcribing…" : "Speak")), for: .normal)
        record.isEnabled = hasFullAccess && (!active || (recording || !processing) && !commandPending)
        insert.isEnabled = hasFullAccess && hasTranscript && !VerseBridge.isRecording && !processing && !commandPending
        if !hasFullAccess {
            status.text = "Enable Full Access for Verse in Settings → Keyboards."
        } else if !VerseBridge.errorText.isEmpty {
            status.text = VerseBridge.errorText
        } else if recording {
            status.text = "Listening…"
        } else if processing {
            status.text = VerseBridge.statusText.isEmpty ? "Transcribing…" : VerseBridge.statusText
        } else if hasTranscript {
            status.text = VerseBridge.transcriptText
        } else if !active {
            status.text = "Open Verse and start a keyboard session, then return here."
        } else {
            status.text = "Tap Speak, then Stop. Your words appear here."
        }
    }

    private var sessionIsActive: Bool {
        let now = Date().timeIntervalSince1970
        return VerseBridge.sessionExpiresAt > now && now - VerseBridge.sessionHeartbeatAt < 3
    }

    private var isProcessing: Bool {
        guard VerseBridge.errorText.isEmpty else { return false }
        return !VerseBridge.pendingJobID.isEmpty || VerseBridge.statusText == "Uploading…" || VerseBridge.statusText == "Transcribing…"
    }

    @objc private func toggleRecording() {
        guard hasFullAccess else { return }
        guard sessionIsActive else {
            if let url = URL(string: "verse://keyboard") {
                extensionContext?.open(url)
            }
            return
        }
        guard VerseBridge.isRecording || !isProcessing,
              VerseBridge.commandID == VerseBridge.acknowledgedCommandID else { return }
        if !VerseBridge.isRecording { insertedID = VerseBridge.transcriptID }
        VerseBridge.send(VerseBridge.isRecording ? "stop" : "start")
        refresh()
    }

    @objc private func insertTranscript() {
        let text = VerseBridge.transcriptText
        guard insert.isEnabled, !text.isEmpty, VerseBridge.transcriptID != insertedID else { return }
        textDocumentProxy.insertText(text)
        insertedID = VerseBridge.transcriptID
        refresh()
    }

    @objc private func deleteCharacter() {
        textDocumentProxy.deleteBackward()
    }
}
