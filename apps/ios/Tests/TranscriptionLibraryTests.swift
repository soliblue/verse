import XCTest
@testable import Verse

@MainActor
final class TranscriptionLibraryTests: XCTestCase {
    func testPendingSelectionSurvivesRestartAndMetadataIsNotAudio() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let pending = root.appendingPathComponent("pending")
        try FileManager.default.createDirectory(at: pending, withIntermediateDirectories: true)
        let library = TranscriptionLibrary(directory: root.appendingPathComponent("library"), pendingDirectory: pending)
        let audio = pending.appendingPathComponent("Recording-keyboard-ABCD1234-5678-4ABC-9123-123456789ABC.m4a")
        try Data([1, 2, 3]).write(to: audio)
        let selection = SpeechSelection(onDevice: true, model: "medium", language: "de", style: .custom, customPrompt: "Keep it concise.")
        try library.saveSelection(selection, for: audio)
        let restored = TranscriptionLibrary(directory: library.directory, pendingDirectory: pending)
        XCTAssertEqual(restored.selection(for: audio), selection)
        XCTAssertEqual(restored.pendingAudio(), [audio])
        XCTAssertEqual(TranscriptionLibrary.localID(for: audio), TranscriptionLibrary.localID(for: URL(fileURLWithPath: "/different/" + audio.lastPathComponent)))
        try restored.removePending(audio)
        XCTAssertTrue(restored.pendingAudio().isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: audio.appendingPathExtension("json").path))
    }

    func testLocalAudioAndOriginalSurviveSaveAndPendingRemoval() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let library = TranscriptionLibrary(directory: root.appendingPathComponent("library"), pendingDirectory: root)
        let audio = root.appendingPathComponent("Recording-app-test.m4a")
        let bytes = Data([1, 4, 9, 16])
        try bytes.write(to: audio)
        let name = try library.keepAudio(audio, id: "local-test")
        var item = fixture(id: "local-test", local: true)
        item.localAudioName = name
        item = item.applying(.init(original: "um hello", text: "Hello", style: .casual, fallback: nil))
        try library.save([item])
        try library.removePending(audio)
        let restored = try XCTUnwrap(library.load().first)
        XCTAssertTrue(restored.isLocal)
        XCTAssertEqual(restored.text, "Hello")
        XCTAssertEqual(restored.originalText, "um hello")
        XCTAssertTrue(restored.hasRewrite)
        XCTAssertEqual(try Data(contentsOf: library.audio(for: restored)), bytes)
        try library.deleteAudio(for: restored)
        XCTAssertThrowsError(try library.audio(for: restored))
    }

    func testServerRefreshRetainsLocalHistoryAndCanonicalRewrites() {
        let local = fixture(id: "local-test", local: true)
        let remote = fixture(id: "server-test")
        let styled = remote.applying(.init(original: "hello", text: "Hello!", style: .casual, fallback: nil))
        let merged = TranscriptionLibrary.merging(server: [remote], cached: [local, styled, fixture(id: "deleted-server")])
        XCTAssertEqual(Set(merged.map(\.id)), ["local-test", "server-test"])
        XCTAssertEqual(merged.first { $0.id == "server-test" }?.text, "Hello!")
        var changed = remote
        changed.text = "new original"
        XCTAssertEqual(TranscriptionLibrary.merging(server: [changed], cached: [styled]).first?.text, "new original")
    }

    func testRewriteLeaseOnlyItsOwnerCanRelease() throws {
        let id = UUID().uuidString
        defer { VerseBridge.removeProcessingState(for: id) }
        let owner = try XCTUnwrap(VerseBridge.claimRewrite(for: id))
        XCTAssertNil(VerseBridge.claimRewrite(for: id))
        VerseBridge.releaseRewrite(for: id, owner: "different-owner")
        XCTAssertNil(VerseBridge.claimRewrite(for: id))
        VerseBridge.releaseRewrite(for: id, owner: owner)
        XCTAssertNotNil(VerseBridge.claimRewrite(for: id))
    }

    func testFirstOutputWinsAndDeletionPreventsRecreation() throws {
        let id = UUID().uuidString
        let first = TranscriptRewriteResult(original: "hello", text: "Hey", style: .casual, fallback: nil)
        let second = TranscriptRewriteResult(original: "hello", text: "Hello!", style: .polished, fallback: nil)
        XCTAssertEqual(VerseBridge.saveRewrite(first, for: id), first)
        XCTAssertEqual(VerseBridge.saveRewrite(second, for: id), first)
        let different = TranscriptRewriteResult.original("unrelated", style: .original)
        XCTAssertEqual(VerseBridge.saveRewrite(different, for: id), different)
        VerseBridge.invalidateTranscription(id)
        XCTAssertNil(VerseBridge.rewriteResult(for: id))
        XCTAssertEqual(VerseBridge.saveRewrite(first, for: id).fallback, .cancelled)
        XCTAssertNil(VerseBridge.rewriteResult(for: id))
    }

    private func fixture(id: String, local: Bool = false) -> Transcription {
        Transcription(id: id, filename: "recording.m4a", state: "completed", model: "medium", language: "auto",
                      detectedLanguage: "en", text: "hello", durationSeconds: 2, error: nil,
                      createdAt: "2026-09-06T09:00:00Z", updatedAt: "2026-09-06T09:00:00Z", origin: .app,
                      engine: local ? "on-device" : nil)
    }
}
