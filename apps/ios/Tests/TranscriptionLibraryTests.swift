import Security
import XCTest
@testable import Verse

@MainActor
final class TranscriptionLibraryTests: XCTestCase {
    func testSharedKeychainIsAvailable() throws {
        let group = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "VerseKeychainAccessGroup") as? String)
        XCTAssertFalse(group.contains("$("))
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccessGroup as String: group,
            kSecAttrService as String: "soli.verse.tests",
            kSecAttrAccount as String: UUID().uuidString
        ]
        let data = Data("Keychain test".utf8)
        var values = query
        values[kSecValueData as String] = data
        values[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(values as CFDictionary, nil)
        defer { SecItemDelete(query as CFDictionary) }
        XCTAssertEqual(status, errSecSuccess, "Shared Keychain group \(group): \(SecCopyErrorMessageString(status, nil) as String? ?? String(status))")
        var lookup = query
        lookup[kSecReturnData as String] = true
        var result: CFTypeRef?
        XCTAssertEqual(SecItemCopyMatching(lookup as CFDictionary, &result), errSecSuccess)
        XCTAssertEqual(result as? Data, data)
    }

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

    func testServerRefreshRetainsHistoryAndCanonicalRewrites() {
        let local = fixture(id: "local-test", local: true)
        let remote = fixture(id: "server-test")
        let styled = remote.applying(.init(original: "hello", text: "Hello!", style: .casual, fallback: nil))
        let merged = TranscriptionLibrary.merging(server: [remote], cached: [local, styled, fixture(id: "cached-server")])
        XCTAssertEqual(Set(merged.map(\.id)), ["local-test", "server-test", "cached-server"])
        XCTAssertEqual(merged.first { $0.id == "server-test" }?.text, "Hello!")
        var changed = remote
        changed.text = "new original"
        XCTAssertEqual(TranscriptionLibrary.merging(server: [changed], cached: [styled]).first?.text, "new original")
    }

    func testLegacyPendingSelectionStillDecodes() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let library = TranscriptionLibrary(directory: root, pendingDirectory: root)
        let audio = root.appendingPathComponent("Recording-app-original.m4a")
        let selection = SpeechSelection(onDevice: false, model: "medium", language: "ar", style: .polished, customPrompt: "")
        try JSONEncoder().encode(selection).write(to: audio.appendingPathExtension("json"))
        XCTAssertEqual(library.selection(for: audio), selection)
        XCTAssertEqual(library.pendingTranscription(for: audio)?.isRerun, false)
    }

    func testRerunRetainsRecordingOriginAndSelectionAcrossRestart() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let library = TranscriptionLibrary(directory: root.appendingPathComponent("library"), pendingDirectory: root.appendingPathComponent("pending"))
        let source = root.appendingPathComponent("source.m4a")
        let bytes = Data([2, 4, 8, 16])
        try bytes.write(to: source)
        var item = fixture(id: "second-version", local: true)
        item.recordingID = "original-recording"
        item.origin = .keyboard
        let archive = try library.keepAudio(source, id: item.recordingKey)
        let selection = SpeechSelection(onDevice: false, model: "large-v3", language: "de", style: .custom, customPrompt: "Keep the original tone.")
        let first = try library.prepareRerun(audio: source, item: item, selection: selection, localAudioName: archive)
        let second = try library.prepareRerun(audio: source, item: item, selection: selection, localAudioName: archive)
        let restored = TranscriptionLibrary(directory: library.directory, pendingDirectory: library.pendingDirectory)
        let context = try XCTUnwrap(restored.pendingTranscription(for: first))
        XCTAssertTrue(context.isRerun)
        XCTAssertEqual(context.recordingID, "original-recording")
        XCTAssertEqual(context.origin, .keyboard)
        XCTAssertEqual(context.filename, item.filename)
        XCTAssertEqual(context.selection, selection)
        XCTAssertEqual(context.localAudioName, archive)
        XCTAssertEqual(try Data(contentsOf: first), bytes)
        XCTAssertNotEqual(SpeechAPI.recordingIdentifier(for: first), SpeechAPI.recordingIdentifier(for: second))
        XCTAssertNotNil(SpeechAPI.recordingIdentifier(for: first))
        try restored.saveSelection(selection, for: first)
        XCTAssertEqual(restored.pendingTranscription(for: first), context)
        try restored.removePending(first)
        XCTAssertEqual(restored.pendingAudio(), [second])
        XCTAssertTrue(FileManager.default.fileExists(atPath: library.directory.appendingPathComponent(archive).path))
    }

    func testRefreshPreservesVersionIdentityArchivedAudioAndSelection() throws {
        var cached = fixture(id: "cloud-version")
        cached.recordingID = "original-recording"
        cached.localAudioName = "original-recording.m4a"
        cached.origin = .keyboard
        cached.customPrompt = "Do not translate."
        cached = cached.applying(.init(original: "hello", text: "Hello!", style: .custom, fallback: nil))
        var incoming = fixture(id: "cloud-version")
        incoming.filename = "Rerun-generated.m4a"
        incoming.origin = .unknown
        let restored = try XCTUnwrap(TranscriptionLibrary.merging(server: [incoming], cached: [cached]).first)
        XCTAssertEqual(restored.recordingKey, "original-recording")
        XCTAssertEqual(restored.localAudioName, "original-recording.m4a")
        XCTAssertEqual(restored.filename, cached.filename)
        XCTAssertEqual(restored.origin, .keyboard)
        XCTAssertEqual(restored.selection, cached.selection)
        XCTAssertEqual(restored.text, "Hello!")
        XCTAssertEqual(restored.originalText, "hello")
        XCTAssertNil(restored.completionNotificationBody(enabled: true, appIsActive: false))
    }

    func testDeletingOneVersionKeepsSharedAudioUntilLastVersionIsRemoved() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let library = TranscriptionLibrary(directory: root.appendingPathComponent("library"), pendingDirectory: root)
        let source = root.appendingPathComponent("audio.m4a")
        try Data([1, 2, 3]).write(to: source)
        let name = try library.keepAudio(source, id: "recording")
        var first = fixture(id: "first", local: true)
        first.localAudioName = name
        var second = fixture(id: "second")
        second.localAudioName = name
        second.recordingID = first.recordingKey
        try library.deleteAudio(for: first, retaining: [second])
        XCTAssertNoThrow(try library.audio(for: second))
        try library.deleteAudio(for: second)
        XCTAssertThrowsError(try library.audio(for: second))
        XCTAssertEqual(try library.keepAudio(source, id: "rerun", existingName: name), name)
        XCTAssertEqual(try Data(contentsOf: library.audio(for: second)), Data([1, 2, 3]))
        XCTAssertThrowsError(try library.keepAudio(source, id: "rerun", existingName: "../outside.m4a"))
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
