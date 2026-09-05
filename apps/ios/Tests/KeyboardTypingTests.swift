import UIKit
import XCTest
@testable import Verse

@MainActor
final class KeyboardTypingTests: XCTestCase {
    func testTypingShiftNumbersAndDelete() throws {
        let keyboard = KeyboardTypingView(frame: CGRect(x: 0, y: 0, width: 390, height: 210))
        var text = ""
        keyboard.insertText = { text += $0 }
        keyboard.deleteBackward = { if !text.isEmpty { text.removeLast() } }
        try tap("h", in: keyboard)
        try tap("i", in: keyboard)
        try tap("Space", in: keyboard)
        try tap("Shift", in: keyboard)
        try tap("Q", in: keyboard)
        try tap("q", in: keyboard)
        try tap("Numbers", in: keyboard)
        try tap("1", in: keyboard)
        try tap("More symbols", in: keyboard)
        try tap("[", in: keyboard)
        try tap("Delete", in: keyboard)
        try tap("Return", in: keyboard)
        XCTAssertEqual(text, "hi Qq1\n")
    }

    func testDoubleShiftLocksCaps() throws {
        let keyboard = KeyboardTypingView()
        var text = ""
        keyboard.insertText = { text += $0 }
        try tap("Shift", in: keyboard)
        try tap("Shift", in: keyboard)
        try tap("A", in: keyboard)
        try tap("B", in: keyboard)
        XCTAssertEqual(text, "AB")
    }

    func testWaveformUsesLayersAndResetsAfterRecording() {
        let waveform = KeyboardAudioWaveView(frame: CGRect(x: 0, y: 0, width: 100, height: 44))
        waveform.layoutIfNeeded()
        waveform.update(level: 1, recording: true)
        XCTAssertFalse(waveform.isHidden)
        XCTAssertEqual(waveform.layer.sublayers?.count, 11)
        XCTAssertEqual(waveform.layer.sublayers?.last?.bounds.height, 28)
        waveform.update(level: 0, recording: false)
        XCTAssertTrue(waveform.isHidden)
        XCTAssertTrue(waveform.layer.sublayers?.allSatisfy { $0.bounds.height == 3 } == true)
    }

    private func tap(_ label: String, in view: UIView) throws {
        let button = try XCTUnwrap(buttons(in: view).first { $0.accessibilityLabel == label })
        button.sendActions(for: .touchUpInside)
    }

    private func buttons(in view: UIView) -> [UIButton] {
        (view as? UIButton).map { [$0] } ?? view.subviews.flatMap { buttons(in: $0) }
    }
}
