import UIKit
import XCTest
@testable import Verse

@MainActor
final class KeyboardRenderingTests: XCTestCase {
    func testPollerDeallocatesSynchronously() {
        weak var releasedPoller: KeyboardTranscriptionPoller?
        autoreleasepool {
            let poller = KeyboardTranscriptionPoller()
            releasedPoller = poller
            withExtendedLifetime(poller) { XCTAssertNotNil(releasedPoller) }
        }
        XCTAssertNil(releasedPoller)
    }

    func testKeyboardDeclaresHeightBeforeHosting() throws {
        let controller = KeyboardViewController()
        controller.isPreview = true
        controller.loadViewIfNeeded()
        let root = try XCTUnwrap(controller.inputView)
        XCTAssertTrue(root === controller.view)
        XCTAssertEqual(root.inputViewStyle, .keyboard)
        XCTAssertTrue(root.allowsSelfSizing)
        XCTAssertEqual(root.bounds.height, KeyboardViewController.contentHeight)
        XCTAssertEqual(root.intrinsicContentSize.height, KeyboardViewController.contentHeight)
        XCTAssertEqual(root.systemLayoutSizeFitting(CGSize(width: 402, height: 0)), CGSize(width: 402, height: KeyboardViewController.contentHeight))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.addSubview(root)
        defer { root.removeFromSuperview() }
        XCTAssertEqual(root.bounds.width, 402)
        XCTAssertEqual(root.systemLayoutSizeFitting(.zero), CGSize(width: 402, height: KeyboardViewController.contentHeight))
    }

    func testVoiceIsDefaultAndUsesTheSystemKeyboardBacking() throws {
        let (window, controller) = installedController()
        defer { controller.view.removeFromSuperview(); window.isHidden = true }
        let root = try XCTUnwrap(controller.inputView)
        let voice = try XCTUnwrap(descendant(in: root, identifiedBy: "keyboard-voice-panel") as? KeyboardVoicePanel)
        let typing = try XCTUnwrap(descendant(in: root, identifiedBy: "keyboard-typing-surface"))
        let toolbar = try XCTUnwrap(descendant(in: root, identifiedBy: "keyboard-toolbar"))
        XCTAssertEqual(root.inputViewStyle, .keyboard)
        XCTAssertEqual(root.backgroundColor, .clear)
        XCTAssertEqual(voice.backgroundColor, .clear)
        XCTAssertEqual(voice.waveform.backgroundColor, .clear)
        XCTAssertTrue(toolbar.backgroundColor == nil || toolbar.backgroundColor == .clear)
        XCTAssertFalse(voice.isHidden)
        XCTAssertTrue(typing.isHidden)
    }

    func testTypingRemainsAvailableAtItsExistingHeight() throws {
        let (window, controller) = installedController(typing: true)
        defer { controller.view.removeFromSuperview(); window.isHidden = true }
        let root = try XCTUnwrap(controller.inputView)
        let voice = try XCTUnwrap(descendant(in: root, identifiedBy: "keyboard-voice-panel"))
        let typing = try XCTUnwrap(descendant(in: root, identifiedBy: "keyboard-typing-surface"))
        XCTAssertTrue(voice.isHidden)
        XCTAssertFalse(typing.isHidden)
        XCTAssertEqual(root.bounds.height, 260)
        XCTAssertEqual(root.intrinsicContentSize.height, 260)
        XCTAssertNotNil(descendant(in: typing, identifiedBy: "keyboard-key-q"))
    }

    func testVoiceControlsFitPortraitWidths() throws {
        for width in [CGFloat(320), 402, 440] {
            let (window, controller) = installedController(width: width)
            defer { controller.view.removeFromSuperview(); window.isHidden = true }
            let root = try XCTUnwrap(controller.inputView)
            let panel = try XCTUnwrap(descendant(in: root, identifiedBy: "keyboard-voice-panel") as? KeyboardVoicePanel)
            let record = try XCTUnwrap(descendant(in: root, identifiedBy: "keyboard-record") as? UIButton)
            let citrus = try XCTUnwrap(descendant(in: root, identifiedBy: "keyboard-citrus") as? UIImageView)
            let toolbar = try XCTUnwrap(descendant(in: root, identifiedBy: "keyboard-toolbar"))
            XCTAssertEqual(toolbar.frame.height, 52, accuracy: 0.5)
            XCTAssertEqual(panel.frame.height, 208, accuracy: 0.5)
            XCTAssertTrue(panel.bounds.contains(panel.actionFrame))
            XCTAssertEqual(panel.actionFrame.midX, panel.bounds.midX, accuracy: 0.5)
            XCTAssertGreaterThanOrEqual(record.bounds.width, 44)
            XCTAssertGreaterThanOrEqual(record.bounds.height, 44)
            XCTAssertEqual(record.convert(record.bounds, to: root), citrus.convert(citrus.bounds, to: root))
            XCTAssertEqual(record.convert(record.bounds, to: root).midX, root.bounds.midX, accuracy: 0.5)
            XCTAssertFalse(citrus.isHidden)
            XCTAssertNotNil(citrus.image)
            for control in [record as UIView, citrus, panel.waveform, panel.globe] {
                XCTAssertTrue(root.bounds.contains(control.convert(control.bounds, to: root)), "\(control.accessibilityIdentifier ?? "control") at \(width)")
            }
            controller.previewWaveform(level: 1)
            root.layoutIfNeeded()
            controller.viewDidLayoutSubviews()
            XCTAssertTrue(citrus.isHidden)
            XCTAssertFalse(panel.waveform.isHidden)
            XCTAssertEqual(record.accessibilityLabel, "Stop recording")
            let stopFrame = record.convert(record.bounds, to: root)
            XCTAssertEqual(stopFrame.height, 44, accuracy: 0.5)
            XCTAssertEqual(root.bounds.maxX - stopFrame.maxX, 16, accuracy: 0.5)
            XCTAssertEqual(stopFrame.minY, toolbar.convert(toolbar.bounds, to: root).minY + 8, accuracy: 0.5)
            XCTAssertTrue(root.bounds.contains(stopFrame))
        }
    }

    func testProcessingIndicatorRetainsContrastWhileDisabled() throws {
        for typing in [false, true] {
            let (window, controller) = installedController(typing: typing, processing: true)
            defer { controller.view.removeFromSuperview(); window.isHidden = true }
            let button = try XCTUnwrap(descendant(in: controller.view, identifiedBy: "keyboard-record") as? UIButton)
            let configuration = try XCTUnwrap(button.configuration)
            let transform = try XCTUnwrap(configuration.activityIndicatorColorTransformer)
            let expected = typing ? UIColor(red: 0.89, green: 0.29, blue: 0.04, alpha: 1) : .white
            XCTAssertFalse(button.isEnabled)
            XCTAssertTrue(configuration.showsActivityIndicator)
            XCTAssertEqual(transform(.clear), expected)
            XCTAssertEqual(transform(.gray), expected)
        }
    }

    func testVoiceWaveformUses49BoundedBars() throws {
        let (window, waveform) = installedWaveform(voice: true)
        defer { waveform.removeFromSuperview(); window.isHidden = true }
        for _ in 0..<49 { waveform.update(level: 1, recording: true) }
        let bars = try XCTUnwrap(waveform.layer.sublayers)
        XCTAssertEqual(bars.count, 49)
        for bar in bars {
            XCTAssertEqual(bar.bounds.height, 80, accuracy: 0.001)
            XCTAssertTrue(waveform.bounds.insetBy(dx: -0.5, dy: -0.5).contains(bar.frame))
        }
        for level in [Double.infinity, .nan, -1, 2] {
            waveform.update(level: level, recording: true)
            for bar in bars {
                XCTAssertTrue(bar.bounds.height.isFinite)
                XCTAssertGreaterThanOrEqual(bar.bounds.height, 3)
                XCTAssertLessThanOrEqual(bar.bounds.height, 80)
            }
        }
    }

    func testVoiceWaveformInterpolatesWithoutLayoutReset() throws {
        try XCTSkipIf(UIAccessibility.isReduceMotionEnabled)
        let (window, waveform) = installedWaveform(voice: true)
        defer { waveform.removeFromSuperview(); window.isHidden = true }
        waveform.update(level: 1, recording: true)
        let bar = try XCTUnwrap(waveform.layer.sublayers?.last)
        waveform.setNeedsLayout()
        waveform.layoutIfNeeded()
        let animation = try XCTUnwrap(bar.animation(forKey: "level") as? CABasicAnimation)
        XCTAssertEqual(animation.keyPath, "bounds.size.height")
        XCTAssertEqual(animation.duration, 0.1, accuracy: 0.0001)
        XCTAssertEqual(animation.toValue as? CGFloat, 80)
        XCTAssertEqual(bar.animationKeys(), ["level"])
    }

    func testVoiceDurationTracksRecordingOnly() throws {
        let panel = KeyboardVoicePanel(frame: CGRect(x: 0, y: 0, width: 402, height: 208))
        let duration = try XCTUnwrap(descendant(in: panel, identifiedBy: "keyboard-recording-duration") as? UILabel)
        let now = Date().timeIntervalSince1970
        panel.update(level: 0.5, recording: true, startedAt: now - 68)
        XCTAssertEqual(duration.text, "1:08")
        XCTAssertFalse(duration.isHidden)
        panel.update(level: 0, recording: false, startedAt: 0)
        XCTAssertTrue(duration.isHidden)
        XCTAssertTrue(panel.waveform.isHidden)
    }

    func testWaveformInterpolatesAtSampleCadence() throws {
        try XCTSkipIf(UIAccessibility.isReduceMotionEnabled)
        let (window, waveform) = installedWaveform()
        defer { waveform.removeFromSuperview(); window.isHidden = true }
        waveform.update(level: 1, recording: true)
        let bar = try XCTUnwrap(waveform.layer.sublayers?.last)
        let animation = try XCTUnwrap(bar.animation(forKey: "level") as? CABasicAnimation)
        XCTAssertEqual(animation.keyPath, "bounds.size.height")
        XCTAssertEqual(animation.duration, 0.1, accuracy: 0.0001)
        XCTAssertEqual(animation.fromValue as? CGFloat, 3)
        XCTAssertEqual(animation.toValue as? CGFloat, 28)
        XCTAssertEqual(bar.bounds.height, 28)
    }

    func testUnchangedLayoutKeepsRunningWaveformAnimation() throws {
        try XCTSkipIf(UIAccessibility.isReduceMotionEnabled)
        let (window, waveform) = installedWaveform()
        defer { waveform.removeFromSuperview(); window.isHidden = true }
        waveform.update(level: 0.5, recording: true)
        let bar = try XCTUnwrap(waveform.layer.sublayers?.last)
        XCTAssertNotNil(bar.animation(forKey: "level"))
        waveform.setNeedsLayout()
        waveform.layoutIfNeeded()
        let animation = try XCTUnwrap(bar.animation(forKey: "level") as? CABasicAnimation)
        XCTAssertEqual(animation.duration, 0.1, accuracy: 0.0001)
        XCTAssertEqual(bar.animationKeys(), ["level"])
    }

    func testStoppingWaveformRemovesAnimations() {
        let (window, waveform) = installedWaveform()
        defer { waveform.removeFromSuperview(); window.isHidden = true }
        waveform.update(level: 1, recording: true)
        waveform.update(level: 0, recording: false)
        XCTAssertTrue(waveform.isHidden)
        for bar in waveform.layer.sublayers ?? [] {
            XCTAssertNil(bar.animation(forKey: "level"))
            XCTAssertEqual(bar.bounds.height, 3)
        }
    }

    func testWaveformUpdateCost() {
        let (window, waveform) = installedWaveform()
        defer { waveform.removeFromSuperview(); window.isHidden = true }
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        measure(metrics: [XCTClockMetric()], options: options) {
            for sample in 0..<120 {
                waveform.update(level: Double(sample % 11) / 10, recording: true)
            }
        }
    }

    func testVoiceWaveformUpdateCost() {
        let (window, waveform) = installedWaveform(voice: true)
        defer { waveform.removeFromSuperview(); window.isHidden = true }
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        measure(metrics: [XCTClockMetric()], options: options) {
            for sample in 0..<120 {
                waveform.update(level: Double(sample % 11) / 10, recording: true)
                waveform.setNeedsLayout()
                waveform.layoutIfNeeded()
            }
        }
    }

    private func installedController(width: CGFloat = 402, typing: Bool = false, processing: Bool = false) -> (UIWindow, KeyboardViewController) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 874))
        let controller = KeyboardViewController()
        controller.isPreview = true
        controller.previewsTyping = typing
        controller.previewsProcessing = processing
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: width, height: KeyboardViewController.contentHeight)
        window.addSubview(controller.view)
        controller.viewWillAppear(false)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        controller.viewDidLayoutSubviews()
        return (window, controller)
    }

    private func descendant(in root: UIView, identifiedBy identifier: String) -> UIView? {
        if root.accessibilityIdentifier == identifier { return root }
        for view in root.subviews {
            if let result = descendant(in: view, identifiedBy: identifier) { return result }
        }
        return nil
    }

    private func installedWaveform(voice: Bool = false) -> (UIWindow, KeyboardAudioWaveView) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let waveform = voice ? KeyboardAudioWaveView(barCount: 49, maximumHeight: 80) : KeyboardAudioWaveView()
        waveform.frame = voice ? CGRect(x: 0, y: 0, width: 362, height: 96) : CGRect(x: 0, y: 0, width: 120, height: 44)
        window.addSubview(waveform)
        waveform.layoutIfNeeded()
        return (window, waveform)
    }
}
