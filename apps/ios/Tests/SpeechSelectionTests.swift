import XCTest
@testable import Verse

@MainActor
final class SpeechSelectionTests: XCTestCase {
    func testUnifiedModelsHaveDistinctEngineIDsAndLabels() {
        XCTAssertEqual(SpeechModelChoice.all.count, 9)
        XCTAssertEqual(Set(SpeechModelChoice.all.map(\.id)).count, 9)
        XCTAssertEqual(SpeechModelChoice.all.filter(\.onDevice).map(\.model), LocalSpeechEngine.modelChoices.map(\.id))
        XCTAssertEqual(SpeechModelChoice.all.filter { !$0.onDevice }.map(\.model), ["small", "medium", "large-v3"])
        XCTAssertEqual(SpeechModelChoice(onDevice: true, model: "medium").title, "Local Medium")
        XCTAssertEqual(SpeechModelChoice(onDevice: false, model: "medium").title, "Cloud Medium")
        XCTAssertEqual(SpeechModelChoice(onDevice: true, model: "turbo").title, "Local Large v3 Turbo")
    }

    func testChangingModelKeepsRecordingOptionsAndDoesNotChangeDefaults() {
        let defaults = SpeechSelection.current
        let original = SpeechSelection(onDevice: true, model: "medium", language: "ar", style: .custom, customPrompt: "Keep my tone.")
        let result = original.replacingModel(.init(onDevice: false, model: "large-v3"))
        XCTAssertFalse(result.onDevice)
        XCTAssertEqual(result.model, "large-v3")
        XCTAssertEqual(result.language, "ar")
        XCTAssertEqual(result.style, .custom)
        XCTAssertEqual(result.customPrompt, "Keep my tone.")
        XCTAssertEqual(SpeechSelection.current, defaults)
        XCTAssertEqual(original.model, "medium")
    }

    func testDisabledWritingPreservesPreferenceButSnapshotsOriginal() {
        let enabled = VerseBridge.writingEnabled
        let style = VerseBridge.writingStyle
        defer {
            VerseBridge.writingStyle = style
            VerseBridge.writingEnabled = enabled
        }
        VerseBridge.writingStyle = "casual"
        VerseBridge.writingEnabled = false
        XCTAssertEqual(SpeechSelection.current.style, .original)
        XCTAssertEqual(VerseBridge.writingStyle, "casual")
        VerseBridge.writingEnabled = true
        XCTAssertEqual(SpeechSelection.current.style, .casual)
    }
}
