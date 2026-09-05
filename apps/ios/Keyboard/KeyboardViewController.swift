import UIKit

final class KeyboardViewController: UIInputViewController {
    private let status = UILabel()
    private let preview = UITextView()
    private let record = UIButton(type: .system)
    private let insert = UIButton(type: .system)
    private let next = UIButton(type: .system)
    private var timer: Timer?
    private var insertedID = ""
    private let poller = KeyboardTranscriptionPoller()

    override func viewDidLoad() {
        super.viewDidLoad()
        let ink = UIColor(red: 0.12, green: 0.16, blue: 0.10, alpha: 1)
        let cream = UIColor(red: 1, green: 0.97, blue: 0.85, alpha: 1)
        view.backgroundColor = UIColor(red: 0.988, green: 0.902, blue: 0.259, alpha: 1)
        view.tintColor = ink
        view.clipsToBounds = true
        let citrus = UIImageView(image: UIImage(named: "Citrus"))
        citrus.contentMode = .scaleAspectFit
        citrus.clipsToBounds = true
        citrus.layer.cornerRadius = 80
        citrus.isAccessibilityElement = false
        citrus.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(citrus)
        status.font = .systemFont(ofSize: 13, weight: .semibold)
        status.textColor = UIColor(red: 0, green: 0.40, blue: 0.22, alpha: 1)
        status.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        preview.font = .systemFont(ofSize: 20, weight: .medium)
        preview.textColor = ink
        preview.backgroundColor = .clear
        preview.isEditable = false
        preview.isSelectable = false
        preview.textContainerInset = .zero
        preview.textContainer.lineFragmentPadding = 0
        preview.accessibilityLabel = "Transcript or recording guidance"
        var recordStyle = UIButton.Configuration.filled()
        recordStyle.baseBackgroundColor = cream
        recordStyle.baseForegroundColor = ink
        recordStyle.cornerStyle = .capsule
        recordStyle.imagePadding = 10
        recordStyle.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var result = attributes
            result.font = .systemFont(ofSize: 20, weight: .semibold)
            return result
        }
        record.configuration = recordStyle
        record.addTarget(self, action: #selector(toggleRecording), for: .touchUpInside)
        insert.setTitle("Insert", for: .normal)
        insert.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        insert.accessibilityLabel = "Insert transcript"
        insert.addTarget(self, action: #selector(insertTranscript), for: .touchUpInside)
        next.setImage(UIImage(systemName: "globe"), for: .normal)
        next.accessibilityLabel = "Next keyboard"
        next.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        let delete = UIButton(type: .system)
        delete.setImage(UIImage(systemName: "delete.left"), for: .normal)
        delete.accessibilityLabel = "Delete"
        delete.addTarget(self, action: #selector(deleteCharacter), for: .touchUpInside)
        let enter = UIButton(type: .system)
        enter.setImage(UIImage(systemName: "return"), for: .normal)
        enter.accessibilityLabel = "Return"
        enter.addTarget(self, action: #selector(insertReturn), for: .touchUpInside)
        for button in [next, delete, enter] {
            button.backgroundColor = cream
            button.layer.cornerRadius = 22
            let width = button.widthAnchor.constraint(equalToConstant: 44)
            width.priority = .defaultHigh
            width.isActive = true
            button.heightAnchor.constraint(equalToConstant: 48).isActive = true
        }
        let heading = UIStackView(arrangedSubviews: [status, insert])
        let insertWidth = insert.widthAnchor.constraint(equalToConstant: 60)
        insertWidth.priority = .defaultHigh
        insertWidth.isActive = true
        let row = UIStackView(arrangedSubviews: [next, delete, record, enter])
        row.spacing = 10
        row.alignment = .center
        record.heightAnchor.constraint(equalToConstant: 54).isActive = true
        let stack = UIStackView(arrangedSubviews: [heading, preview, row])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalToConstant: 240),
            citrus.widthAnchor.constraint(equalToConstant: 160),
            citrus.heightAnchor.constraint(equalToConstant: 160),
            citrus.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 50),
            citrus.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 90),
            heading.heightAnchor.constraint(equalToConstant: 44),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16)
        ])
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        next.isHidden = !needsInputModeSwitchKey
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        insertedID = VerseBridge.lastInsertedTranscriptID
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        timer?.invalidate()
        timer = nil
        poller.cancel()
    }

    private func refresh() {
        if hasFullAccess { poller.poll() }
        let active = sessionIsActive
        let recording = active && VerseBridge.isRecording
        let commandPending = active && VerseBridge.commandID != VerseBridge.acknowledgedCommandID
        let processing = isProcessing
        if hasFullAccess, !recording, !processing,
           DictationInsertionPolicy.canAutomaticallyInsert(
            transcriptID: VerseBridge.transcriptID, text: VerseBridge.transcriptText,
            insertedID: VerseBridge.lastInsertedTranscriptID, requestedID: VerseBridge.insertionTranscriptID,
            readyAt: VerseBridge.insertionReadyAt, now: Date().timeIntervalSince1970
           ) {
            textDocumentProxy.insertText(VerseBridge.transcriptText)
            insertedID = VerseBridge.transcriptID
            VerseBridge.lastInsertedTranscriptID = insertedID
            VerseBridge.insertionTranscriptID = ""
        }
        let hasTranscript = DictationInsertionPolicy.canInsert(transcriptID: VerseBridge.transcriptID, text: VerseBridge.transcriptText, insertedID: insertedID)
        record.setTitle(!active ? "Open Verse" : (recording ? "Stop" : (processing ? "Working…" : "Speak")), for: .normal)
        record.setImage(UIImage(systemName: recording ? "stop.fill" : "mic.fill"), for: .normal)
        record.isEnabled = hasFullAccess && (!active || (recording || !processing) && !commandPending)
        insert.isEnabled = hasFullAccess && hasTranscript && !VerseBridge.isRecording && !processing && !commandPending
        insert.isHidden = !hasTranscript
        let message: String
        if !hasFullAccess {
            status.text = "Setup needed"
            message = "Enable Full Access for Verse in Settings → Keyboards."
        } else if !VerseBridge.errorText.isEmpty {
            status.text = "Something went wrong"
            message = VerseBridge.errorText
        } else if recording {
            status.text = "Listening…"
            message = "Tap Stop when you’re done."
        } else if processing {
            status.text = VerseBridge.statusText.isEmpty ? "Transcribing…" : VerseBridge.statusText
            message = "Turning speech into text."
        } else if hasTranscript {
            status.text = "Ready to insert"
            message = VerseBridge.transcriptText
        } else if !active {
            status.text = "Microphone off"
            message = "Start Dictate with Verse from Control Center or your Action Button. Or open Verse."
        } else {
            status.text = "Ready"
            message = "Tap Speak to start."
        }
        if preview.text != message {
            preview.text = message
            preview.setContentOffset(.zero, animated: false)
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
        VerseBridge.lastInsertedTranscriptID = insertedID
        VerseBridge.insertionTranscriptID = ""
        refresh()
    }

    @objc private func deleteCharacter() {
        textDocumentProxy.deleteBackward()
    }

    @objc private func insertReturn() {
        textDocumentProxy.insertText("\n")
    }
}
