import UIKit
import XCTest
@testable import Verse

@MainActor
final class KeyboardRenderingTests: XCTestCase {
    func testKeyboardDeclaresHeightBeforeHosting() throws {
        let controller = KeyboardViewController()
        controller.isPreview = true
        controller.loadViewIfNeeded()
        let root = try XCTUnwrap(controller.inputView)
        XCTAssertTrue(root === controller.view)
        XCTAssertTrue(root.allowsSelfSizing)
        XCTAssertEqual(root.bounds.height, KeyboardViewController.contentHeight)
        XCTAssertEqual(root.intrinsicContentSize.height, KeyboardViewController.contentHeight)
        XCTAssertEqual(root.systemLayoutSizeFitting(CGSize(width: 402, height: 0)), CGSize(width: 402, height: KeyboardViewController.contentHeight))
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

    private func installedWaveform() -> (UIWindow, KeyboardAudioWaveView) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let waveform = KeyboardAudioWaveView(frame: CGRect(x: 0, y: 0, width: 120, height: 44))
        window.addSubview(waveform)
        waveform.layoutIfNeeded()
        return (window, waveform)
    }
}
