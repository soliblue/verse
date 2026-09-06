import XCTest
@testable import Verse

@MainActor
final class TranscriptStyleTests: XCTestCase {
    func testStylesAndAvailabilityKeepOriginalAsDefault() {
        XCTAssertEqual(TranscriptStyle.allCases, [.original, .casual, .polished, .custom])
        XCTAssertNil(TranscriptStyle.original.instructions())
        XCTAssertTrue(AppleWritingAvailability.available.isAvailable)
        XCTAssertFalse(AppleWritingAvailability.appleIntelligenceNotEnabled.isAvailable)
        XCTAssertTrue(AppleWritingAvailability.appleIntelligenceNotEnabled.canOpenSettings)
        XCTAssertFalse(AppleWritingAvailability.deviceNotEligible.canOpenSettings)
        XCTAssertTrue(AppleWritingAvailability.requiresUpdate.message.contains("iOS 26"))
        XCTAssertTrue(AppleWritingAvailability.appleIntelligenceNotEnabled.message.contains("Apple Intelligence & Siri"))
    }

    func testCustomPromptIsOptionalTrimmedAndBounded() throws {
        XCTAssertNil(TranscriptStyle.custom.instructions(customPrompt: " \n "))
        XCTAssertEqual(TranscriptStyle.custom.instructions(customPrompt: "  Keep it friendly.\n"), "Keep it friendly.")
        XCTAssertEqual(try XCTUnwrap(TranscriptStyle.custom.instructions(customPrompt: String(repeating: "a", count: 800))).count, 500)
        let instructions = try XCTUnwrap(TranscriptWritingPolicy.instructions(style: .custom, customPrompt: "Use short sentences."))
        XCTAssertTrue(instructions.contains("names, numbers, dates, URLs"))
        XCTAssertTrue(instructions.contains("Do not translate"))
        XCTAssertTrue(instructions.contains("Use short sentences."))
    }

    func testIncompleteBlankAndVerboseOutputFallsBack() {
        XCTAssertNil(TranscriptWritingPolicy.validatedText("Hey there", original: "Hello"))
        XCTAssertNil(TranscriptWritingPolicy.validatedText("\n<verse-end>\n", original: "Hello"))
        XCTAssertNil(TranscriptWritingPolicy.validatedText(String(repeating: "a", count: 300) + "\n<verse-end>", original: "Hello"))
        XCTAssertNil(TranscriptWritingPolicy.validatedText("Hi <verse-end> there\n<verse-end>", original: "Hello"))
        XCTAssertEqual(TranscriptWritingPolicy.validatedText(" Hey there!\n<verse-end>\n", original: "Hello there"), "Hey there!")
    }

    func testNumberChangesAreRejected() {
        let original = "Meet Ahmed at 19:30. Bring 2 tickets."
        XCTAssertEqual(TranscriptWritingPolicy.validatedText("Ahmed, let's meet at 19:30. Bring 2 tickets.\n<verse-end>", original: original), "Ahmed, let's meet at 19:30. Bring 2 tickets.")
        XCTAssertNil(TranscriptWritingPolicy.validatedText("Meet Ahmed at 19:00. Bring 2 tickets.\n<verse-end>", original: original))
        XCTAssertNil(TranscriptWritingPolicy.validatedText("Meet Ahmed at 19:30.\n<verse-end>", original: original))
        XCTAssertNil(TranscriptWritingPolicy.validatedText("Meet Ahmed at 19:30. Bring 2 tickets and 5 euros.\n<verse-end>", original: original))
    }

    func testSignsSeparatorsAndPercentagesCannotChange() {
        let changes = [
            ("-10", "10"), ("+10", "-10"), ("−10", "10"),
            ("1.5", "1:5"), ("1,500", "1.500"), ("19:30", "19.30"),
            ("10/12", "10:12"), ("10–12", "10-12"), ("25%", "25"),
            ("١٫٥", "١٥"), ("١٬٥٠٠", "١٫٥٠٠")
        ]
        for (before, after) in changes {
            XCTAssertNil(TranscriptWritingPolicy.validatedText("It is \(after).\n<verse-end>", original: "It is \(before)."), "Accepted numeric change from \(before) to \(after)")
        }
    }

    func testMorningAndEveningStayDistinctButFormattingCanChange() {
        XCTAssertNil(TranscriptWritingPolicy.validatedText("Meet at 9am.\n<verse-end>", original: "Meet at 9pm."))
        XCTAssertNil(TranscriptWritingPolicy.validatedText("Meet at 9.\n<verse-end>", original: "Meet at 9pm."))
        XCTAssertNil(TranscriptWritingPolicy.validatedText("Meet at 9pm.\n<verse-end>", original: "Meet at 9."))
        XCTAssertEqual(TranscriptWritingPolicy.validatedText("See you at 9 PM!\n<verse-end>", original: "Meet at 9 p.m."), "See you at 9 PM!")
        XCTAssertEqual(TranscriptWritingPolicy.validatedText("Save 25 %.\n<verse-end>", original: "Save 25%."), "Save 25 %.")
    }

    func testDatesURLsAndSentencePunctuationRemainValid() {
        let original = "Um, meet on 2026-09-06 at 19:30. Tickets: https://soli.blue/2026/09/06?count=2."
        let rewritten = "Let's meet on 2026-09-06 at 19:30. Tickets are at https://soli.blue/2026/09/06?count=2!"
        XCTAssertEqual(TranscriptWritingPolicy.validatedText(rewritten + "\n<verse-end>", original: original), rewritten)
        XCTAssertEqual(TranscriptWritingPolicy.validatedText("Bring 2!\n<verse-end>", original: "Bring 2."), "Bring 2!")
    }

    func testArabicIsDetectedInsideMixedLanguageMessages() {
        XCTAssertTrue(TranscriptWritingPolicy.containsArabic("Hey حبيبي see you soon"))
        XCTAssertTrue(TranscriptWritingPolicy.containsArabic("مرحبا"))
        XCTAssertFalse(TranscriptWritingPolicy.containsArabic("Hey, bis später!"))
        XCTAssertFalse(TranscriptWritingPolicy.containsArabic("Meet at ١٩:٣٠"))
    }

    func testRewriteRetainsOriginalAndRoundTrips() throws {
        let value = TranscriptRewriteResult(original: "Uh yeah I am coming", text: "Yeah, I'm coming.", style: .casual, fallback: nil)
        XCTAssertTrue(value.isRewritten)
        XCTAssertEqual(value.original, "Uh yeah I am coming")
        let restored = try JSONDecoder().decode(TranscriptRewriteResult.self, from: JSONEncoder().encode(value))
        XCTAssertEqual(restored, value)
        let fallback = TranscriptRewriteResult.original(value.original, style: .custom, fallback: .failed)
        XCTAssertFalse(fallback.isRewritten)
        XCTAssertEqual(fallback.text, value.original)
        XCTAssertEqual(try JSONDecoder().decode(TranscriptRewriteResult.self, from: JSONEncoder().encode(fallback)), fallback)
    }

    func testOriginalAndEmptyCustomNeverNeedAppleModel() async {
        let service = AppleWritingService()
        let original = await service.rewrite(text: "Hey", style: .original)
        XCTAssertEqual(original.text, "Hey")
        XCTAssertNil(original.fallback)
        let emptyCustom = await service.rewrite(text: "Hey", style: .custom)
        XCTAssertEqual(emptyCustom.text, "Hey")
        XCTAssertEqual(emptyCustom.fallback, .emptyPrompt)
        let long = String(repeating: "a", count: TranscriptWritingPolicy.maximumInputBytes + 1)
        let tooLong = await service.rewrite(text: long, style: .casual)
        XCTAssertEqual(tooLong.text, long)
        XCTAssertEqual(tooLong.fallback, .tooLong)
    }

    func testCancelledRewriteRetainsOriginal() async {
        let task = Task {
            let service = AppleWritingService()
            await Task.yield()
            return await service.rewrite(text: "Keep this", style: .casual)
        }
        task.cancel()
        let result = await task.value
        XCTAssertEqual(result.text, "Keep this")
        XCTAssertEqual(result.fallback, .cancelled)
    }
}
