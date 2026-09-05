import XCTest
@testable import Verse

final class DictationInsertionTests: XCTestCase {
    func testFreshDictationInsertsOnce() {
        XCTAssertTrue(DictationInsertionPolicy.canAutomaticallyInsert(transcriptID: "new", text: "Hello", insertedID: "old", requestedID: "new", readyAt: 100, now: 101))
        XCTAssertFalse(DictationInsertionPolicy.canAutomaticallyInsert(transcriptID: "new", text: "Hello", insertedID: "new", requestedID: "new", readyAt: 100, now: 101))
    }

    func testUnrequestedAndStaleResultsDoNotInsert() {
        XCTAssertFalse(DictationInsertionPolicy.canAutomaticallyInsert(transcriptID: "new", text: "Hello", insertedID: "old", requestedID: "", readyAt: 100, now: 101))
        XCTAssertFalse(DictationInsertionPolicy.canAutomaticallyInsert(transcriptID: "new", text: "Hello", insertedID: "old", requestedID: "new", readyAt: 100, now: 220))
        XCTAssertFalse(DictationInsertionPolicy.canAutomaticallyInsert(transcriptID: "new", text: "Hello", insertedID: "old", requestedID: "new", readyAt: 100, now: 99))
    }

    func testEmptySpeechNeverInserts() {
        XCTAssertFalse(DictationInsertionPolicy.canInsert(transcriptID: "new", text: "", insertedID: "old"))
        XCTAssertFalse(DictationInsertionPolicy.canInsert(transcriptID: "", text: "Hello", insertedID: "old"))
    }

    func testStaleSharedSnapshotCannotRepeatLocalInsertion() {
        XCTAssertFalse(DictationInsertionPolicy.canAutomaticallyInsert(transcriptID: "new", text: "Hello", insertedID: "old", requestedID: "new", readyAt: 100, now: 101, locallyInsertedID: "new"))
    }
}
