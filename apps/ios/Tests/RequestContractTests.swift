import Foundation
import XCTest
@testable import Morrow

@MainActor
final class RequestContractTests: XCTestCase {
    func testFeedbackRequestUsesBackendKeys() throws {
        let data = try JSONEncoder().encode(
            FeedbackRequest(storyID: "story-1", kind: .moreLikeThis, value: true)
        )
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["story_id"] as? String, "story-1")
        XCTAssertEqual(object["kind"] as? String, "more_like_this")
        XCTAssertEqual(object["value"] as? Bool, true)
        XCTAssertNil(object["storyID"])
    }

    func testDeepDiveRequestUsesBackendKey() throws {
        let data = try JSONEncoder().encode(DeepDiveRequest(storyID: "story-2"))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["story_id"] as? String, "story-2")
    }
}
