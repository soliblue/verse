import Foundation
import XCTest
@testable import Morrow

@MainActor
final class FixtureContractTests: XCTestCase {
    func testBundledEditionDecodesAndHasFiniteShape() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "first-edition", withExtension: "json"))
        let edition = try JSONDecoder().decode(EditionPayload.self, from: Data(contentsOf: url))

        XCTAssertEqual(edition.items.count, 10)
        XCTAssertEqual(edition.items.map(\.position), Array(1...10))
        XCTAssertTrue(edition.items.allSatisfy { !$0.citations.isEmpty })
        XCTAssertTrue(edition.items.allSatisfy { $0.sourceURL.scheme == "https" })
        XCTAssertTrue(edition.items.allSatisfy { $0.feedback == nil })
        XCTAssertTrue(edition.items.allSatisfy { $0.resolvedDeepDive.status == .notRequested })
    }

    func testBundledTopicsDecode() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "default-topics", withExtension: "json"))
        let topics = try JSONDecoder().decode(TopicList.self, from: Data(contentsOf: url)).topics

        XCTAssertFalse(topics.isEmpty)
        XCTAssertTrue(topics.contains { $0.kind == .exclusion })
        XCTAssertEqual(topics.map(\.position), Array(1...topics.count))
    }
}
