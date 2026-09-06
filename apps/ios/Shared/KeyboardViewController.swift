#if !VERSE_WIDGET
import UIKit
import SwiftUI

final class KeyboardViewController: UIInputViewController {
    static let contentHeight: CGFloat = 260
    #if DEBUG
    var isPreview = false
    var previewsColdStart = false
    var previewsTyping = false
    var previewsProcessing = false
    var previewTextInput: ((String) -> Void)?
    var previewDeleteBackward: (() -> Void)?

    func previewWaveform(level: Double) {
        if !recordingPresentation {
            bridge["recordingStartedAt"] = String(Date().timeIntervalSince1970 - 8)
            updatePresentation(active: true, recording: true, busy: false, hasTranscript: false)
            language.isEnabled = false
            model.isEnabled = false
        }
        updateWaveform(level: level, recording: true)
    }
    #endif
    private let language = UIButton(type: .system)
    private let model = UIButton(type: .system)
    private let waveform = KeyboardAudioWaveView()
    private let record = UIButton(type: .system)
    private let launch = UIHostingController(rootView: KeyboardLaunchLink())
    private let insert = UIButton(type: .system)
    private let keyboard = KeyboardTypingView()
    private let voice = KeyboardVoicePanel()
    private let recordingControl = UIView()
    private let controlSlot = UIView()
    private let toolbar = UIStackView()
    private var toolbarHeight: NSLayoutConstraint?
    private let citrus = UIImageView(image: UIImage(named: "CitrusSlice"))
    private var typingEnabled = false
    private var recordingPresentation = false
    private var busyPresentation = false
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
        root.clipsToBounds = true
        root.invalidatePresentation()
        root.heightAnchor.constraint(equalToConstant: Self.contentHeight).isActive = true
        inputView = root
    }

    override func viewDidLoad() {
        super.viewDidLoad()
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
        record.accessibilityIdentifier = "keyboard-record"
        record.addTarget(self, action: #selector(toggleRecording), for: .touchUpInside)
        citrus.contentMode = .scaleAspectFill
        citrus.clipsToBounds = true
        citrus.isUserInteractionEnabled = false
        citrus.accessibilityIdentifier = "keyboard-citrus"
        recordingControl.clipsToBounds = true
        recordingControl.addSubview(citrus)
        record.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        recordingControl.addSubview(record)
        addChild(launch)
        launch.safeAreaRegions = []
        launch.view.frame = recordingControl.bounds
        launch.view.backgroundColor = .clear
        launch.view.translatesAutoresizingMaskIntoConstraints = false
        recordingControl.addSubview(launch.view)
        NSLayoutConstraint.activate([
            launch.view.leadingAnchor.constraint(equalTo: recordingControl.leadingAnchor),
            launch.view.trailingAnchor.constraint(equalTo: recordingControl.trailingAnchor),
            launch.view.topAnchor.constraint(equalTo: recordingControl.topAnchor),
            launch.view.bottomAnchor.constraint(equalTo: recordingControl.bottomAnchor)
        ])
        launch.didMove(toParent: self)
        controlSlot.widthAnchor.constraint(equalToConstant: 44).isActive = true
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
        voice.globe.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        let waveformSpace = UIView()
        waveform.translatesAutoresizingMaskIntoConstraints = false
        waveformSpace.addSubview(waveform)
        NSLayoutConstraint.activate([
            waveform.leadingAnchor.constraint(equalTo: waveformSpace.leadingAnchor),
            waveform.trailingAnchor.constraint(equalTo: waveformSpace.trailingAnchor),
            waveform.topAnchor.constraint(equalTo: waveformSpace.topAnchor),
            waveform.bottomAnchor.constraint(equalTo: waveformSpace.bottomAnchor)
        ])
        let controls: [UIView] = [language, model, waveformSpace, insert, controlSlot]
        for control in controls { toolbar.addArrangedSubview(control) }
        toolbar.accessibilityIdentifier = "keyboard-toolbar"
        toolbar.spacing = 2
        toolbar.isLayoutMarginsRelativeArrangement = true
        toolbar.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        toolbarHeight = toolbar.heightAnchor.constraint(equalToConstant: 52)
        toolbarHeight?.isActive = true
        let body = UIView()
        for surface in [keyboard as UIView, voice] {
            surface.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            surface.frame = body.bounds
            body.addSubview(surface)
        }
        let stack = UIStackView(arrangedSubviews: [toolbar, body])
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        view.addSubview(recordingControl)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 0),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        updateInputMode()
        updateAppearance()
        updatePresentation(active: false, recording: false, busy: false, hasTranscript: false)
    }

    override func textDidChange(_ textInput: UITextInput?) {
        updateAppearance()
        updateTypingContext()
    }

    override func selectionDidChange(_ textInput: UITextInput?) {
        updateTypingContext()
    }

    private func updateTypingContext() {
        guard typingEnabled else { return }
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
        voice.globe.isHidden = !needsInputModeSwitchKey
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let root = inputView as? KeyboardInputView else { return }
        guard root.hasBoundedGeometry else { root.completeLayout(); return }
        let centered = !typingEnabled && !recordingPresentation && !busyPresentation
        recordingControl.frame = centered ? voice.convert(voice.actionFrame, to: view) : controlSlot.convert(controlSlot.bounds, to: view)
        citrus.frame = recordingControl.bounds
        record.frame = recordingControl.bounds
        recordingControl.layoutIfNeeded()
        citrus.layer.cornerRadius = recordingControl.bounds.width / 2
        root.completeLayout()
    }

    private func updateInputMode() {
        var enabled = bridge["typingKeyboardEnabled"] == "true"
        #if DEBUG
        if isPreview { enabled = previewsTyping }
        #endif
        guard enabled != typingEnabled || keyboard.isHidden == enabled else { return }
        typingEnabled = enabled
        keyboard.isHidden = !typingEnabled
        voice.isHidden = typingEnabled
        toolbarHeight?.constant = typingEnabled ? 44 : 52
        toolbar.spacing = typingEnabled ? 2 : 8
        toolbar.directionalLayoutMargins.top = typingEnabled ? 0 : 8
        for button in [language, model] {
            button.layer.cornerRadius = 22
            button.layer.borderWidth = typingEnabled ? 0 : 0.5
            button.layer.borderColor = UIColor.label.withAlphaComponent(0.15).resolvedColor(with: traitCollection).cgColor
        }
        waveform.update(level: 0, recording: false)
        voice.update(level: 0, recording: false, startedAt: 0)
        controlsState = ""
        updateTypingContext()
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
        for button in [language, model] {
            button.layer.borderColor = UIColor.label.withAlphaComponent(0.15).resolvedColor(with: view.traitCollection).cgColor
        }
    }

    private func updateMenus() {
        let selectedLanguage = bridge["language"] ?? "auto"
        let onDevice = bridge["onDeviceTranscriptionEnabled"] != "false"
        let selectedModel = bridge[onDevice ? "localModel" : "model"] ?? "medium"
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
        let choices = onDevice
            ? [("tiny", "Tiny"), ("base", "Base"), ("small", "Small"), ("medium", "Medium"), ("large-v3", "Large"), ("turbo", "Turbo")]
            : [("small", "Small"), ("medium", "Medium"), ("large-v3", "Large")]
        let installed = Set((bridge["localInstalledModels"] ?? "").split(separator: ",").map(String.init))
        var actions: [UIMenuElement] = choices.map { code, name in
            UIAction(title: name, attributes: onDevice && !installed.contains(code) ? .disabled : [], state: selectedModel == code ? .on : .off) { [weak self] _ in
                self?.cancelSnapshot()
                if onDevice {
                    VerseBridge.localModel = code
                } else {
                    VerseBridge.model = code
                }
                self?.bridge[onDevice ? "localModel" : "model"] = code
                self?.updateMenus()
            }
        }
        if onDevice && installed.isEmpty {
            actions.append(UIAction(title: "Download models in Verse", attributes: .disabled) { _ in })
        }
        model.menu = UIMenu(children: actions)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateAppearance()
        updateMenus()
        updateTypingContext()
        #if DEBUG
        if isPreview {
            updatePresentation(active: !previewsColdStart, recording: false, busy: previewsProcessing, hasTranscript: false)
            record.isEnabled = !previewsProcessing
            language.isEnabled = !previewsProcessing
            model.isEnabled = !previewsProcessing
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
            let menusChanged = ["language", "model", "onDeviceTranscriptionEnabled", "localModel", "localInstalledModels"].contains { bridge[$0] != values[$0] }
            bridge = values
            updateInputMode()
            if menusChanged { updateMenus() }
            if hasFullAccess { poller.poll(state: values) }
            render()
        }
    }

    private func value(_ key: String) -> String { bridge[key] ?? "" }

    private func updateWaveform(level: Double, recording: Bool) {
        if typingEnabled {
            waveform.update(level: level, recording: recording)
        } else {
            voice.update(level: level, recording: recording, startedAt: Double(value("recordingStartedAt")) ?? 0)
        }
    }

    private func setMeterActive(_ active: Bool) {
        if active {
            guard meterTimer == nil else { return }
            updateWaveform(level: 0, recording: true)
            let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self, meterTask == nil else { return }
                meterTask = Task { [weak self] in
                    let level = await Task.detached(priority: .userInitiated) { VerseBridge.readAudioLevel() }.value
                    guard !Task.isCancelled, let self else { return }
                    meterTask = nil
                    updateWaveform(level: level, recording: true)
                }
            }
            timer.tolerance = 0.01
            meterTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        } else {
            guard meterTimer != nil || !waveform.isHidden || !voice.waveform.isHidden else { return }
            meterTimer?.invalidate()
            meterTimer = nil
            meterTask?.cancel()
            meterTask = nil
            waveform.update(level: 0, recording: false)
            voice.update(level: 0, recording: false, startedAt: 0)
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
        let nextControlsState = "\(typingEnabled)|\(hasFullAccess)|\(active)|\(recording)|\(commandPending)|\(processing)|\(hasTranscript)|\(value("errorText"))"
        guard nextControlsState != controlsState else { return }
        controlsState = nextControlsState
        language.isEnabled = !recording && !processing && !commandPending
        model.isEnabled = language.isEnabled
        updatePresentation(active: active, recording: recording, busy: processing || commandPending, hasTranscript: hasTranscript)
        record.isEnabled = hasFullAccess && active && (recording || !processing) && !commandPending
        insert.isEnabled = hasFullAccess && hasTranscript && !recording && !processing && !commandPending
        record.accessibilityHint = value("errorText")
    }

    private func updatePresentation(active: Bool, recording: Bool, busy: Bool, hasTranscript: Bool) {
        recordingPresentation = recording
        busyPresentation = busy
        let centered = !typingEnabled && !recording && !busy
        let orange = UIColor(red: 0.89, green: 0.29, blue: 0.04, alpha: 1)
        let ink = UIColor(red: 0.12, green: 0.16, blue: 0.10, alpha: 1)
        let canLaunch = !active && !busy
        record.isHidden = canLaunch
        launch.view.isHidden = !canLaunch
        citrus.isHidden = !centered
        var configuration = UIButton.Configuration.plain()
        configuration.cornerStyle = .capsule
        configuration.baseForegroundColor = centered ? ink : (typingEnabled ? orange : .white)
        let indicatorColor: UIColor = typingEnabled ? orange : .white
        configuration.activityIndicatorColorTransformer = UIConfigurationColorTransformer { _ in indicatorColor }
        configuration.background.backgroundColor = !typingEnabled && !centered ? orange : .clear
        configuration.showsActivityIndicator = busy
        configuration.image = busy ? nil : UIImage(systemName: recording ? "stop.fill" : "waveform")
        configuration.preferredSymbolConfigurationForImage = .init(pointSize: centered ? 25 : 20, weight: .medium)
        record.configuration = configuration
        record.accessibilityLabel = recording ? "Stop recording" : (busy ? "Transcribing" : "Record")
        launch.rootView = KeyboardLaunchLink(foreground: Color(centered ? ink : orange))
        insert.isHidden = !hasTranscript || recording || busy
        if !recording {
            waveform.update(level: 0, recording: false)
            voice.update(level: 0, recording: false, startedAt: 0)
        }
        view.setNeedsLayout()
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
    var hasBoundedGeometry: Bool {
        window != nil && bounds.width.isFinite && bounds.width > 0 &&
        bounds.height.isFinite && abs(bounds.height - KeyboardViewController.contentHeight) <= 0.5
    }

    override var bounds: CGRect {
        didSet {
            if bounds != oldValue { invalidatePresentation() }
        }
    }

    override var frame: CGRect {
        didSet {
            if frame != oldValue { invalidatePresentation() }
        }
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        invalidatePresentation()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        invalidatePresentation()
        if bounds.width == 0, window != nil { frame.size.width = hostWidth }
        invalidateIntrinsicContentSize()
    }

    override func layoutSubviews() {
        if !hasBoundedGeometry { setPresented(false) }
        super.layoutSubviews()
    }

    func invalidatePresentation() {
        setPresented(false)
        setNeedsLayout()
    }

    func completeLayout() {
        setPresented(hasBoundedGeometry)
    }

    private func setPresented(_ presented: Bool) {
        UIView.performWithoutAnimation {
            alpha = presented ? 1 : 0
            isUserInteractionEnabled = presented
            accessibilityElementsHidden = !presented
        }
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: KeyboardViewController.contentHeight)
    }

    override func systemLayoutSizeFitting(_ targetSize: CGSize) -> CGSize {
        let width = targetSize.width > 0 && targetSize.width.isFinite ? targetSize.width : hostWidth
        return CGSize(width: width, height: KeyboardViewController.contentHeight)
    }

    override func systemLayoutSizeFitting(_ targetSize: CGSize, withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority, verticalFittingPriority: UILayoutPriority) -> CGSize {
        systemLayoutSizeFitting(targetSize)
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
