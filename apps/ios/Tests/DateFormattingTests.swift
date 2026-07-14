import XCTest
@testable import Verse

@MainActor
final class DateFormattingTests: XCTestCase {
    func testDatesAlwaysUseEnglish() {
        XCTAssertEqual(DateFormatting.editionDate("2026-07-14"), "Tuesday, July 14, 2026")
        XCTAssertEqual(DateFormatting.shortDate("2026-07-14T12:00:00Z"), "Jul 14, 2026")
    }
}
