import UIKit
import XCTest
@testable import Verse

@MainActor
final class KeyboardTypingTests: XCTestCase {
    func testTypingShiftNumbersAndDelete() throws {
        let keyboard = makeKeyboard()
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
        let keyboard = makeKeyboard()
        var text = ""
        keyboard.insertText = { text += $0 }
        try tap("Shift", in: keyboard)
        try tap("Shift", in: keyboard)
        try tap("A", in: keyboard)
        try tap("B", in: keyboard)
        XCTAssertEqual(text, "AB")
    }

    func testOverlappingTouchesKeepOrderWithoutReplacingKeys() throws {
        let keyboard = makeKeyboard()
        let originalKeys = buttons(in: keyboard).map(ObjectIdentifier.init)
        let a = try center("a", in: keyboard)
        let b = try center("b", in: keyboard)
        var text = ""
        keyboard.insertText = { text += $0 }
        for index in 0..<100 {
            let time = Double(index)
            keyboard.beginTouch(id: index * 2, at: a, time: time)
            keyboard.beginTouch(id: index * 2 + 1, at: b, time: time + 0.005)
            keyboard.endTouch(id: index * 2 + 1, at: b, time: time + 0.01)
            keyboard.endTouch(id: index * 2, at: a, time: time + 0.02)
        }
        XCTAssertEqual(text, String(repeating: "ab", count: 100))
        XCTAssertEqual(buttons(in: keyboard).map(ObjectIdentifier.init), originalKeys)
    }

    func testTwoFingersOnSameKeyBothInsert() throws {
        let keyboard = makeKeyboard()
        let point = try center("o", in: keyboard)
        var text = ""
        keyboard.insertText = { text += $0 }
        keyboard.beginTouch(id: 1, at: point, time: 1)
        keyboard.beginTouch(id: 2, at: point, time: 1.01)
        keyboard.endTouch(id: 2, at: point, time: 1.03)
        keyboard.endTouch(id: 1, at: point, time: 1.05)
        XCTAssertEqual(text, "oo")
    }

    func testRapidTypingRenderingPerformance() throws {
        let reference = makeKeyboard()
        let a = try center("a", in: reference)
        let b = try center("b", in: reference)
        var text = ""
        measure(metrics: [XCTClockMetric()]) {
            let keyboard = makeKeyboard()
            text = ""
            keyboard.insertText = { text += $0 }
            for index in 0..<100 {
                let time = Double(index)
                keyboard.beginTouch(id: index * 2, at: a, time: time)
                keyboard.beginTouch(id: index * 2 + 1, at: b, time: time + 0.005)
                keyboard.endTouch(id: index * 2 + 1, at: b, time: time + 0.01)
                keyboard.endTouch(id: index * 2, at: a, time: time + 0.02)
            }
        }
        XCTAssertEqual(text, String(repeating: "ab", count: 100))
    }

    func testOneShotShiftDoesNotLoseOrCapitalizeSecondOverlappingKey() throws {
        let keyboard = makeKeyboard()
        let originalKeys = buttons(in: keyboard).map(ObjectIdentifier.init)
        try press("Shift", id: 1, time: 1, in: keyboard)
        let a = try center("A", in: keyboard)
        let b = try center("B", in: keyboard)
        var text = ""
        keyboard.insertText = { text += $0 }
        keyboard.beginTouch(id: 2, at: a, time: 2)
        keyboard.beginTouch(id: 3, at: b, time: 2.01)
        keyboard.endTouch(id: 3, at: b, time: 2.02)
        keyboard.endTouch(id: 2, at: a, time: 2.03)
        XCTAssertEqual(text, "Ab")
        XCTAssertEqual(buttons(in: keyboard).map(ObjectIdentifier.init), originalKeys)
    }

    func testAllCharactersTraitKeepsBothOverlappingKeysUppercase() throws {
        let keyboard = makeKeyboard()
        keyboard.updateContext(beforeInput: "", autoCapitalization: .allCharacters, returnKey: .default)
        let a = try center("A", in: keyboard)
        let b = try center("B", in: keyboard)
        var text = ""
        keyboard.insertText = { text += $0 }
        keyboard.beginTouch(id: 1, at: a, time: 1)
        keyboard.beginTouch(id: 2, at: b, time: 1.01)
        keyboard.endTouch(id: 2, at: b, time: 1.02)
        keyboard.endTouch(id: 1, at: a, time: 1.03)
        XCTAssertEqual(text, "AB")
    }

    func testPendingLetterDoesNotConsumeLaterShiftTap() throws {
        let keyboard = makeKeyboard()
        let a = try center("a", in: keyboard)
        var text = ""
        keyboard.insertText = { text += $0 }
        keyboard.beginTouch(id: 1, at: a, time: 1)
        try press("Shift", id: 2, time: 1.1, in: keyboard)
        keyboard.endTouch(id: 1, at: a, time: 1.2)
        try press("B", id: 3, time: 1.3, in: keyboard)
        try press("c", id: 4, time: 2, in: keyboard)
        XCTAssertEqual(text, "aBc")
    }

    func testDisablingAutomaticShiftOnlyAffectsNextLetter() throws {
        let keyboard = makeKeyboard()
        keyboard.updateContext(beforeInput: "", autoCapitalization: .sentences, returnKey: .default)
        var text = ""
        keyboard.insertText = { text += $0 }
        try press("Shift", id: 1, time: 1, in: keyboard)
        try press("a", id: 2, time: 2, in: keyboard)
        try press("Return", id: 3, time: 3, in: keyboard)
        try press("B", id: 4, time: 4, in: keyboard)
        XCTAssertEqual(text, "a\nB")
    }

    func testHeldShiftIsMomentary() throws {
        let keyboard = makeKeyboard()
        let shift = try center("Shift", in: keyboard)
        var text = ""
        keyboard.insertText = { text += $0 }
        keyboard.beginTouch(id: 1, at: shift, time: 1)
        try press("A", id: 2, time: 1.1, in: keyboard)
        try press("B", id: 3, time: 1.2, in: keyboard)
        keyboard.endTouch(id: 1, at: shift, time: 1.3)
        try press("c", id: 4, time: 2, in: keyboard)
        XCTAssertEqual(text, "ABc")
    }

    func testGapsAndOuterEdgesRemainHittable() throws {
        let keyboard = makeKeyboard()
        let q = try key("q", in: keyboard)
        let points = [
            CGPoint(x: q.frame.maxX + 1, y: q.frame.midY),
            CGPoint(x: q.frame.midX, y: q.frame.maxY + 3),
            CGPoint(x: 0, y: q.frame.midY),
            CGPoint(x: keyboard.bounds.maxX - 0.1, y: q.frame.midY)
        ]
        var text = ""
        keyboard.insertText = { text += $0 }
        for (id, point) in points.enumerated() {
            keyboard.beginTouch(id: id, at: point, time: Double(id))
            keyboard.endTouch(id: id, at: point, time: Double(id) + 0.02)
        }
        XCTAssertEqual(text, "qqqp")
    }

    func testSlideCorrectionAndOutsideCancellation() throws {
        let keyboard = makeKeyboard()
        let q = try center("q", in: keyboard)
        let w = try center("w", in: keyboard)
        var text = ""
        keyboard.insertText = { text += $0 }
        keyboard.beginTouch(id: 1, at: q, time: 1)
        XCTAssertEqual(keyboard.visiblePopupTexts, ["q"])
        keyboard.moveTouch(id: 1, at: w, time: 1.1)
        XCTAssertEqual(keyboard.visiblePopupTexts, ["w"])
        keyboard.endTouch(id: 1, at: w, time: 1.2)
        XCTAssertEqual(text, "w")
        keyboard.beginTouch(id: 2, at: q, time: 2)
        keyboard.moveTouch(id: 2, at: CGPoint(x: -100, y: -100), time: 2.1)
        keyboard.endTouch(id: 2, at: CGPoint(x: -100, y: -100), time: 2.2)
        XCTAssertEqual(text, "w")
    }

    func testCancelledFirstTouchDoesNotDiscardCompletedSecondTouch() throws {
        let keyboard = makeKeyboard()
        let a = try center("a", in: keyboard)
        let b = try center("b", in: keyboard)
        var text = ""
        keyboard.insertText = { text += $0 }
        keyboard.beginTouch(id: 1, at: a, time: 1)
        keyboard.beginTouch(id: 2, at: b, time: 1.01)
        keyboard.endTouch(id: 2, at: b, time: 1.02)
        keyboard.cancelTouch(id: 1)
        XCTAssertEqual(text, "b")
    }

    func testPopupShowsImmediatelyThenClearsAfterRelease() async throws {
        let keyboard = makeKeyboard()
        let q = try center("q", in: keyboard)
        keyboard.beginTouch(id: 1, at: q, time: 1)
        XCTAssertEqual(keyboard.visiblePopupTexts, ["q"])
        keyboard.endTouch(id: 1, at: q, time: 1.02)
        XCTAssertEqual(keyboard.visiblePopupTexts, ["q"])
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(keyboard.visiblePopupTexts.isEmpty)
        keyboard.beginTouch(id: 2, at: q, time: 2)
        keyboard.cancelTouch(id: 2)
        XCTAssertTrue(keyboard.visiblePopupTexts.isEmpty)
    }

    func testDeleteRepeatStopsOnReleaseCancellationAndSlideOff() throws {
        let keyboard = makeKeyboard()
        let point = try center("Delete", in: keyboard)
        var deletions = 0
        keyboard.deleteBackward = { deletions += 1 }
        keyboard.beginTouch(id: 1, at: point, time: 1)
        XCTAssertEqual(deletions, 1)
        keyboard.advanceTime(to: 1.37)
        XCTAssertEqual(deletions, 1)
        keyboard.advanceTime(to: 1.39)
        keyboard.advanceTime(to: 1.47)
        XCTAssertEqual(deletions, 3)
        keyboard.endTouch(id: 1, at: point, time: 1.48)
        keyboard.advanceTime(to: 2)
        XCTAssertEqual(deletions, 3)
        keyboard.beginTouch(id: 2, at: point, time: 3)
        keyboard.moveTouch(id: 2, at: CGPoint(x: -100, y: -100), time: 3.1)
        keyboard.advanceTime(to: 4)
        keyboard.cancelTouch(id: 2)
        keyboard.advanceTime(to: 5)
        XCTAssertEqual(deletions, 4)
    }

    func testDeleteOverlappingPendingLetterKeepsOrder() throws {
        let keyboard = makeKeyboard()
        let a = try center("a", in: keyboard)
        let delete = try center("Delete", in: keyboard)
        var text = "hi"
        keyboard.insertText = { text += $0 }
        keyboard.deleteBackward = { if !text.isEmpty { text.removeLast() } }
        keyboard.beginTouch(id: 1, at: a, time: 1)
        keyboard.beginTouch(id: 2, at: delete, time: 1.01)
        keyboard.endTouch(id: 2, at: delete, time: 1.02)
        keyboard.endTouch(id: 1, at: a, time: 1.03)
        XCTAssertEqual(text, "hi")
    }

    func testHoldNumbersSlideInsertsThenReturnsToLetters() throws {
        let keyboard = makeKeyboard()
        let mode = try center("Numbers", in: keyboard)
        var text = ""
        keyboard.insertText = { text += $0 }
        keyboard.beginTouch(id: 1, at: mode, time: 1)
        let one = try center("1", in: keyboard)
        keyboard.moveTouch(id: 1, at: one, time: 1.1)
        keyboard.endTouch(id: 1, at: one, time: 1.2)
        try press("q", id: 2, time: 2, in: keyboard)
        XCTAssertEqual(text, "1q")
    }

    func testDoubleSpacePeriodAndSentenceCapitalization() throws {
        let keyboard = makeKeyboard()
        keyboard.updateContext(beforeInput: "Hello", autoCapitalization: .sentences, returnKey: .send)
        var text = "Hello"
        keyboard.insertText = { text += $0 }
        keyboard.deleteBackward = { if !text.isEmpty { text.removeLast() } }
        try press("Space", id: 1, time: 1, in: keyboard)
        try press("Space", id: 2, time: 1.1, in: keyboard)
        try press("Q", id: 3, time: 2, in: keyboard)
        XCTAssertEqual(text, "Hello. Q")
        XCTAssertEqual(try key("Return", in: keyboard).title(for: .normal), "send")
    }

    func testHoldingSpaceMovesCursorWithoutInserting() throws {
        let keyboard = makeKeyboard()
        let space = try center("Space", in: keyboard)
        var text = ""
        var offsets: [Int] = []
        keyboard.insertText = { text += $0 }
        keyboard.adjustTextPosition = { offsets.append($0) }
        keyboard.beginTouch(id: 1, at: space, time: 1)
        keyboard.advanceTime(to: 1.41)
        keyboard.moveTouch(id: 1, at: CGPoint(x: space.x + 24, y: space.y), time: 1.5)
        keyboard.moveTouch(id: 1, at: CGPoint(x: space.x + 8, y: space.y), time: 1.6)
        keyboard.endTouch(id: 1, at: CGPoint(x: space.x + 8, y: space.y), time: 1.7)
        XCTAssertTrue(text.isEmpty)
        XCTAssertEqual(offsets, [3, -2])
        try press("Space", id: 2, time: 2, in: keyboard)
        XCTAssertEqual(text, " ")
    }

    func testGeometryAcrossPhoneWidthsAndGlobeLayout() throws {
        for width in [320.0, 390.0, 430.0] {
            let keyboard = KeyboardTypingView(frame: CGRect(x: 0, y: 0, width: width, height: 204))
            let q = try key("q", in: keyboard)
            let w = try key("w", in: keyboard)
            let a = try key("a", in: keyboard)
            XCTAssertEqual(q.frame.minX, 5, accuracy: 0.01)
            XCTAssertEqual(q.frame.height, 42, accuracy: 0.01)
            XCTAssertEqual(a.frame.minY - q.frame.minY, 51, accuracy: 0.01)
            XCTAssertEqual(a.frame.minX - q.frame.minX, (w.frame.minX - q.frame.minX) / 2, accuracy: 0.01)
            XCTAssertEqual(try key("p", in: keyboard).frame.maxX, width - 5, accuracy: 0.01)
            let initialSpace = try key("Space", in: keyboard).frame.width
            keyboard.setGlobeVisible(false)
            XCTAssertTrue(keyboard.globeButton.isHidden)
            XCTAssertGreaterThan(try key("Space", in: keyboard).frame.width, initialSpace)
        }
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
        let button = try key(label, in: view)
        button.sendActions(for: .touchUpInside)
    }

    private func makeKeyboard() -> KeyboardTypingView {
        KeyboardTypingView(frame: CGRect(x: 0, y: 0, width: 390, height: 204))
    }

    private func key(_ label: String, in view: UIView) throws -> UIButton {
        try XCTUnwrap(buttons(in: view).first { !$0.isHidden && $0.accessibilityLabel == label })
    }

    private func center(_ label: String, in view: UIView) throws -> CGPoint {
        let frame = try key(label, in: view).frame
        return CGPoint(x: frame.midX, y: frame.midY)
    }

    private func press(_ label: String, id: Int, time: TimeInterval, in keyboard: KeyboardTypingView) throws {
        let point = try center(label, in: keyboard)
        keyboard.beginTouch(id: id, at: point, time: time)
        keyboard.endTouch(id: id, at: point, time: time + 0.02)
    }

    private func buttons(in view: UIView) -> [UIButton] {
        (view as? UIButton).map { [$0] } ?? view.subviews.flatMap { buttons(in: $0) }
    }
}
