#if !VERSE_WIDGET
import UIKit
import SwiftUI

final class KeyboardViewController: UIInputViewController {
    #if DEBUG
    var isPreview = false
    var previewsColdStart = false
    #endif
    private let language = UIButton(type: .system)
    private let model = UIButton(type: .system)
    private let waveform = KeyboardAudioWaveView()
    private let record = UIButton(type: .system)
    private let launch = UIHostingController(rootView: KeyboardLaunchLink())
    private let insert = UIButton(type: .system)
    private let keyboard = KeyboardTypingView()
    private var timer: Timer?
    private var insertedID = ""
    private let poller = KeyboardTranscriptionPoller()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.clipsToBounds = true
        language.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        language.accessibilityLabel = "Transcription language"
        model.setImage(UIImage(systemName: "cpu"), for: .normal)
        model.accessibilityLabel = "Transcription model"
        for button in [language, model] {
            button.showsMenuAsPrimaryAction = true
            button.widthAnchor.constraint(equalToConstant: 44).isActive = true
        }
        updateMenus()
        waveform.backgroundColor = .clear
        waveform.isAccessibilityElement = false
        var configuration = UIButton.Configuration.plain()
        configuration.baseForegroundColor = UIColor(red: 0.89, green: 0.29, blue: 0.04, alpha: 1)
        configuration.cornerStyle = .capsule
        record.configuration = configuration
        record.accessibilityIdentifier = "keyboard-record"
        record.addTarget(self, action: #selector(toggleRecording), for: .touchUpInside)
        let recordingControl = UIView()
        record.translatesAutoresizingMaskIntoConstraints = false
        recordingControl.addSubview(record)
        addChild(launch)
        launch.view.backgroundColor = .clear
        launch.view.translatesAutoresizingMaskIntoConstraints = false
        recordingControl.addSubview(launch.view)
        launch.didMove(toParent: self)
        NSLayoutConstraint.activate([
            recordingControl.widthAnchor.constraint(equalToConstant: 44),
            record.widthAnchor.constraint(equalToConstant: 44),
            record.trailingAnchor.constraint(equalTo: recordingControl.trailingAnchor),
            record.topAnchor.constraint(equalTo: recordingControl.topAnchor),
            record.bottomAnchor.constraint(equalTo: recordingControl.bottomAnchor),
            launch.view.leadingAnchor.constraint(equalTo: recordingControl.leadingAnchor),
            launch.view.trailingAnchor.constraint(equalTo: recordingControl.trailingAnchor),
            launch.view.topAnchor.constraint(equalTo: recordingControl.topAnchor),
            launch.view.bottomAnchor.constraint(equalTo: recordingControl.bottomAnchor)
        ])
        insert.setImage(UIImage(systemName: "text.badge.plus"), for: .normal)
        insert.accessibilityLabel = "Insert transcript"
        insert.addTarget(self, action: #selector(insertTranscript), for: .touchUpInside)
        insert.widthAnchor.constraint(equalToConstant: 44).isActive = true
        keyboard.insertText = { [weak self] text in self?.textDocumentProxy.insertText(text) }
        keyboard.deleteBackward = { [weak self] in self?.textDocumentProxy.deleteBackward() }
        keyboard.globeButton.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        let waveformSpace = UIView()
        waveform.translatesAutoresizingMaskIntoConstraints = false
        waveformSpace.addSubview(waveform)
        NSLayoutConstraint.activate([
            waveform.leadingAnchor.constraint(equalTo: waveformSpace.leadingAnchor),
            waveform.trailingAnchor.constraint(equalTo: waveformSpace.trailingAnchor),
            waveform.topAnchor.constraint(equalTo: waveformSpace.topAnchor),
            waveform.bottomAnchor.constraint(equalTo: waveformSpace.bottomAnchor)
        ])
        let toolbar = UIStackView(arrangedSubviews: [language, model, waveformSpace, insert, recordingControl])
        toolbar.spacing = 2
        toolbar.heightAnchor.constraint(equalToConstant: 40).isActive = true
        let stack = UIStackView(arrangedSubviews: [toolbar, keyboard])
        stack.axis = .vertical
        stack.spacing = 9
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalToConstant: 270),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 5),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -5),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 7),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -7)
        ])
        updateAppearance()
    }

    override func textDidChange(_ textInput: UITextInput?) { updateAppearance() }

    private func updateAppearance() {
        var dark = textDocumentProxy.keyboardAppearance == .dark || (textDocumentProxy.keyboardAppearance == .default && traitCollection.userInterfaceStyle == .dark)
        #if DEBUG
        if isPreview { dark = ProcessInfo.processInfo.arguments.contains("--keyboard-dark-ui-testing") }
        #endif
        view.backgroundColor = dark ? UIColor(white: 0.10, alpha: 1) : UIColor(red: 0.82, green: 0.83, blue: 0.85, alpha: 1)
        view.tintColor = dark ? .white : .black
        keyboard.updateAppearance(dark: dark)
    }

    private func updateMenus() {
        language.setTitle(VerseBridge.language == "auto" ? "AUTO" : VerseBridge.language.uppercased(), for: .normal)
        language.accessibilityValue = VerseBridge.language
        language.menu = UIMenu(children: [
            ("auto", "Automatic"), ("en", "English"), ("ar", "Arabic"), ("de", "German"),
            ("fr", "French"), ("es", "Spanish"), ("it", "Italian"), ("pt", "Portuguese"),
            ("tr", "Turkish"), ("zh", "Chinese"), ("ja", "Japanese"), ("ko", "Korean"),
            ("ru", "Russian"), ("hi", "Hindi")
        ].map { code, name in
            UIAction(title: name, state: VerseBridge.language == code ? .on : .off) { [weak self] _ in
                VerseBridge.language = code
                self?.updateMenus()
            }
        })
        model.accessibilityValue = VerseBridge.model
        model.menu = UIMenu(children: [("small", "Small"), ("medium", "Medium"), ("large-v3", "Large")].map { code, name in
            UIAction(title: name, state: VerseBridge.model == code ? .on : .off) { [weak self] _ in
                VerseBridge.model = code
                self?.updateMenus()
            }
        })
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateAppearance()
        updateMenus()
        #if DEBUG
        if isPreview {
            record.setImage(UIImage(systemName: "waveform"), for: .normal)
            record.accessibilityLabel = "Record"
            record.isHidden = previewsColdStart
            launch.view.isHidden = !previewsColdStart
            insert.isHidden = true
            waveform.isHidden = true
            return
        }
        #endif
        insertedID = VerseBridge.lastInsertedTranscriptID
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in self?.refresh() }
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
        language.isEnabled = !recording && !processing && !commandPending
        model.isEnabled = language.isEnabled
        waveform.update(level: VerseBridge.audioLevel, recording: recording)
        let canLaunch = !active && !processing
        record.isHidden = canLaunch
        launch.view.isHidden = !canLaunch
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
        record.configuration?.showsActivityIndicator = processing || commandPending
        record.setImage(processing || commandPending ? nil : UIImage(systemName: recording ? "stop.fill" : "waveform"), for: .normal)
        record.accessibilityLabel = recording ? "Stop recording" : (processing ? "Transcribing" : "Record")
        record.isEnabled = hasFullAccess && active && (recording || !processing) && !commandPending
        insert.isEnabled = hasFullAccess && hasTranscript && !VerseBridge.isRecording && !processing && !commandPending
        insert.isHidden = !hasTranscript
        record.accessibilityHint = VerseBridge.errorText.isEmpty ? "" : VerseBridge.errorText
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
        guard hasFullAccess, sessionIsActive else { return }
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
}
#endif
