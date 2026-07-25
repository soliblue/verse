import Foundation
import XCTest
@testable import Verse

@MainActor
final class FixtureContractTests: XCTestCase {
    func testBundledEditionDecodesAndHasFiniteShape() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "first-edition", withExtension: "json"))
        let edition = try JSONDecoder().decode(EditionPayload.self, from: Data(contentsOf: url))

        XCTAssertTrue((8...12).contains(edition.items.count))
        XCTAssertEqual(edition.items.map(\.position), Array(1...edition.items.count))
        XCTAssertEqual(Set(edition.items.map(\.id)).count, edition.items.count)
        XCTAssertTrue(edition.items.allSatisfy { !$0.title.isEmpty })
        XCTAssertTrue(edition.items.allSatisfy { !$0.summary.isEmpty })
        XCTAssertTrue(edition.items.allSatisfy { !$0.sourceName.isEmpty })
        XCTAssertTrue(edition.items.allSatisfy { !$0.citations.isEmpty })
        XCTAssertTrue(edition.items.allSatisfy { $0.sourceURL.scheme == "https" })
        XCTAssertTrue(edition.items.allSatisfy { $0.feedback == nil || $0.feedback == .empty })
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
