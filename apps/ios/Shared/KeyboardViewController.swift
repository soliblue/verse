#if !VERSE_WIDGET
import UIKit
import SwiftUI

final class KeyboardViewController: UIInputViewController {
    static let contentHeight: CGFloat = 260
    #if DEBUG
    var isPreview = false
    var previewsColdStart = false
    var previewTextInput: ((String) -> Void)?
    var previewDeleteBackward: (() -> Void)?

    func previewWaveform(level: Double) {
        if waveform.isHidden {
            record.setImage(UIImage(systemName: "stop.fill"), for: .normal)
            record.accessibilityLabel = "Stop recording"
            language.isEnabled = false
            model.isEnabled = false
            launch.view.isHidden = true
            insert.isHidden = true
        }
        waveform.update(level: level, recording: true)
    }
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
    private var snapshotTask: Task<Void, Never>?
    private var meterTimer: Timer?
    private var meterTask: Task<Void, Never>?
    private var bridge: [String: String] = [:]
    private var darkAppearance: Bool?
    private var controlsState = ""

    override func loadView() {
        let root = KeyboardInputView(frame: CGRect(x: 0, y: 0, width: 0, height: Self.contentHeight), inputViewStyle: .keyboard)
        root.autoresizingMask = .flexibleWidth
        root.allowsSelfSizing = true
        inputView = root
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.clipsToBounds = false
        view.accessibilityIdentifier = "keyboard-content"
        language.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        language.accessibilityLabel = "Transcription language"
        model.setImage(UIImage(systemName: "cpu"), for: .normal)
        model.setPreferredSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: 18, weight: .regular), forImageIn: .normal)
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
        record.setPreferredSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: 20, weight: .regular), forImageIn: .normal)
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
        let insertWidth = insert.widthAnchor.constraint(equalToConstant: 44)
        insertWidth.priority = .defaultHigh
        insertWidth.isActive = true
        keyboard.accessibilityIdentifier = "keyboard-typing-surface"
        keyboard.insertText = { [weak self] text in
            guard let self else { return }
            #if DEBUG
            if isPreview { previewTextInput?(text); return }
            #endif
            textDocumentProxy.insertText(text)
        }
        keyboard.deleteBackward = { [weak self] in
            guard let self else { return }
            #if DEBUG
            if isPreview { previewDeleteBackward?(); return }
            #endif
            textDocumentProxy.deleteBackward()
        }
        keyboard.adjustTextPosition = { [weak self] offset in
            guard let self else { return }
            textDocumentProxy.adjustTextPosition(byCharacterOffset: offset)
            updateTypingContext()
        }
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
        toolbar.accessibilityIdentifier = "keyboard-toolbar"
        toolbar.spacing = 2
        toolbar.isLayoutMarginsRelativeArrangement = true
        toolbar.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 11, bottom: 0, trailing: 11)
        toolbar.heightAnchor.constraint(equalToConstant: 44).isActive = true
        let stack = UIStackView(arrangedSubviews: [toolbar, keyboard])
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalToConstant: Self.contentHeight),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 0),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        updateAppearance()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        updateAppearance()
        updateTypingContext()
    }

    override func selectionDidChange(_ textInput: UITextInput?) {
        updateTypingContext()
    }

    private func updateTypingContext() {
        #if DEBUG
        if isPreview { return }
        #endif
        keyboard.updateContext(beforeInput: textDocumentProxy.documentContextBeforeInput,
                               autoCapitalization: textDocumentProxy.autocapitalizationType ?? .sentences,
                               returnKey: textDocumentProxy.returnKeyType ?? .default)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        keyboard.setGlobeVisible(needsInputModeSwitchKey)
    }

    private func updateAppearance() {
        var dark = textDocumentProxy.keyboardAppearance == .dark || (textDocumentProxy.keyboardAppearance == .default && traitCollection.userInterfaceStyle == .dark)
        #if DEBUG
        if isPreview { dark = ProcessInfo.processInfo.arguments.contains("--keyboard-dark-ui-testing") }
        #endif
        guard darkAppearance != dark else { return }
        darkAppearance = dark
        view.overrideUserInterfaceStyle = dark ? .dark : .light
        view.backgroundColor = .clear
        view.tintColor = dark ? .white : .black
        keyboard.updateAppearance(dark: dark)
    }

    private func updateMenus() {
        let selectedLanguage = bridge["language"] ?? "auto"
        let selectedModel = bridge["model"] ?? "medium"
        language.setTitle(selectedLanguage == "auto" ? "AUTO" : selectedLanguage.uppercased(), for: .normal)
        language.accessibilityValue = selectedLanguage
        language.menu = UIMenu(children: [
            ("auto", "Automatic"), ("en", "English"), ("ar", "Arabic"), ("de", "German"),
            ("fr", "French"), ("es", "Spanish"), ("it", "Italian"), ("pt", "Portuguese"),
            ("tr", "Turkish"), ("zh", "Chinese"), ("ja", "Japanese"), ("ko", "Korean"),
            ("ru", "Russian"), ("hi", "Hindi")
        ].map { code, name in
            UIAction(title: name, state: selectedLanguage == code ? .on : .off) { [weak self] _ in
                self?.cancelSnapshot()
                VerseBridge.language = code
                self?.bridge["language"] = code
                self?.updateMenus()
            }
        })
        model.accessibilityValue = selectedModel
        model.menu = UIMenu(children: [("small", "Small"), ("medium", "Medium"), ("large-v3", "Large")].map { code, name in
            UIAction(title: name, state: selectedModel == code ? .on : .off) { [weak self] _ in
                self?.cancelSnapshot()
                VerseBridge.model = code
                self?.bridge["model"] = code
                self?.updateMenus()
            }
        })
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateAppearance()
        updateMenus()
        updateTypingContext()
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
        insertedID = ""
        controlsState = ""
        insert.isEnabled = false
        record.isEnabled = false
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in self?.refresh() }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        timer?.invalidate()
        timer = nil
        cancelSnapshot()
        poller.cancel()
        setMeterActive(false)
    }

    private func cancelSnapshot() {
        snapshotTask?.cancel()
        snapshotTask = nil
    }

    private func refresh() {
        guard snapshotTask == nil else { return }
        snapshotTask = Task { [weak self] in
            let values = await Task.detached(priority: .userInitiated) { VerseBridge.snapshot() }.value
            guard !Task.isCancelled, let self else { return }
            snapshotTask = nil
            let menusChanged = bridge["language"] != values["language"] || bridge["model"] != values["model"]
            bridge = values
            if menusChanged { updateMenus() }
            if hasFullAccess { poller.poll(state: values) }
            render()
        }
    }

    private func value(_ key: String) -> String { bridge[key] ?? "" }

    private func setMeterActive(_ active: Bool) {
        if active {
            guard meterTimer == nil else { return }
            waveform.update(level: 0, recording: true)
            let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self, meterTask == nil else { return }
                meterTask = Task { [weak self] in
                    let level = await Task.detached(priority: .userInitiated) { VerseBridge.readAudioLevel() }.value
                    guard !Task.isCancelled, let self else { return }
                    meterTask = nil
                    waveform.update(level: level, recording: true)
                }
            }
            timer.tolerance = 0.01
            meterTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        } else {
            guard meterTimer != nil || !waveform.isHidden else { return }
            meterTimer?.invalidate()
            meterTimer = nil
            meterTask?.cancel()
            meterTask = nil
            waveform.update(level: 0, recording: false)
        }
    }

    private func render() {
        let active = sessionIsActive
        let recording = active && value("isRecording") == "true"
        let commandPending = active && value("commandID") != value("acknowledgedCommandID")
        let processing = isProcessing
        setMeterActive(recording)
        if insertedID.isEmpty { insertedID = value("lastInsertedTranscriptID") }
        if hasFullAccess, !recording, !processing, !commandPending,
           DictationInsertionPolicy.canAutomaticallyInsert(
            transcriptID: value("transcriptID"), text: value("transcriptText"),
            insertedID: value("lastInsertedTranscriptID"), requestedID: value("insertionTranscriptID"),
            readyAt: Double(value("insertionReadyAt")) ?? 0, now: Date().timeIntervalSince1970,
            locallyInsertedID: insertedID
           ) {
            textDocumentProxy.insertText(value("transcriptText"))
            insertedID = value("transcriptID")
            VerseBridge.lastInsertedTranscriptID = insertedID
            VerseBridge.insertionTranscriptID = ""
            bridge["lastInsertedTranscriptID"] = insertedID
            bridge["insertionTranscriptID"] = ""
            updateTypingContext()
        }
        let hasTranscript = DictationInsertionPolicy.canInsert(transcriptID: value("transcriptID"), text: value("transcriptText"), insertedID: insertedID)
        let nextControlsState = "\(hasFullAccess)|\(active)|\(recording)|\(commandPending)|\(processing)|\(hasTranscript)|\(value("errorText"))"
        guard nextControlsState != controlsState else { return }
        controlsState = nextControlsState
        language.isEnabled = !recording && !processing && !commandPending
        model.isEnabled = language.isEnabled
        let canLaunch = !active && !processing
        record.isHidden = canLaunch
        launch.view.isHidden = !canLaunch
        record.configuration?.showsActivityIndicator = processing || commandPending
        record.setImage(processing || commandPending ? nil : UIImage(systemName: recording ? "stop.fill" : "waveform"), for: .normal)
        record.accessibilityLabel = recording ? "Stop recording" : (processing ? "Transcribing" : "Record")
        record.isEnabled = hasFullAccess && active && (recording || !processing) && !commandPending
        insert.isEnabled = hasFullAccess && hasTranscript && !recording && !processing && !commandPending
        insert.isHidden = !hasTranscript
        record.accessibilityHint = value("errorText")
    }

    private var sessionIsActive: Bool {
        let now = Date().timeIntervalSince1970
        return (Double(value("sessionExpiresAt")) ?? 0) > now && now - (Double(value("sessionHeartbeatAt")) ?? 0) < 3
    }

    private var isProcessing: Bool {
        guard value("errorText").isEmpty else { return false }
        return !value("pendingJobID").isEmpty || value("statusText") == "Uploading…" || value("statusText") == "Transcribing…"
    }

    @objc private func toggleRecording() {
        guard hasFullAccess, sessionIsActive else { return }
        let recording = value("isRecording") == "true"
        guard recording || !isProcessing,
              value("commandID") == value("acknowledgedCommandID") else { return }
        if !recording { insertedID = value("transcriptID") }
        cancelSnapshot()
        bridge["commandID"] = VerseBridge.send(recording ? "stop" : "start")
        render()
        refresh()
    }

    @objc private func insertTranscript() {
        let text = value("transcriptText")
        guard insert.isEnabled, !text.isEmpty, value("transcriptID") != insertedID else { return }
        cancelSnapshot()
        textDocumentProxy.insertText(text)
        insertedID = value("transcriptID")
        VerseBridge.lastInsertedTranscriptID = insertedID
        VerseBridge.insertionTranscriptID = ""
        bridge["lastInsertedTranscriptID"] = insertedID
        bridge["insertionTranscriptID"] = ""
        render()
        updateTypingContext()
        refresh()
    }
}

private final class KeyboardInputView: UIInputView {
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if bounds.width == 0, window != nil { frame.size.width = hostWidth }
        invalidateIntrinsicContentSize()
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: KeyboardViewController.contentHeight)
    }

    override func systemLayoutSizeFitting(_ targetSize: CGSize) -> CGSize {
        let width = targetSize.width > 0 && targetSize.width.isFinite ? targetSize.width : hostWidth
        return CGSize(width: width, height: KeyboardViewController.contentHeight)
    }

    private var hostWidth: CGFloat {
        var ancestor = superview
        while let view = ancestor {
            if view.bounds.width > 0 { return view.bounds.width }
            ancestor = view.superview
        }
        return window?.bounds.width ?? bounds.width
    }
}
#endif
