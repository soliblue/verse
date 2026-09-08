import XCTest
@testable import Verse

@MainActor
final class AudioImportTests: XCTestCase {
    func testAudioRegistrationUsesAlternateViewerWithoutClaimingAllFiles() throws {
        let types = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "CFBundleDocumentTypes") as? [[String: Any]])
        let audio = try XCTUnwrap(types.first { ($0["LSItemContentTypes"] as? [String])?.contains("public.audio") == true })
        XCTAssertEqual(audio["CFBundleTypeRole"] as? String, "Viewer")
        XCTAssertEqual(audio["LSHandlerRank"] as? String, "Alternate")
        for type in types {
            XCTAssertNotEqual(type["LSHandlerRank"] as? String, "Owner")
            XCTAssertFalse((type["LSItemContentTypes"] as? [String] ?? []).contains("public.data"))
        }
    }

    func testPrivateImportsPreserveLocalAndCloudSelectionsAfterSourceRemovalAndRestart() throws {
        let (root, library) = try fixture()
        let defaults = SpeechSelection.current
        let selections = [
            SpeechSelection(onDevice: true, model: "medium", language: "ar", style: .custom, customPrompt: "Keep my own words."),
            SpeechSelection(onDevice: false, model: "large-v3", language: "de", style: .polished, customPrompt: "")
        ]
        var imports: [URL] = []
        for (index, selection) in selections.enumerated() {
            let source = root.appendingPathComponent("Voice note \(index).m4a")
            let bytes = Data([1, 4, 9, UInt8(index)])
            try bytes.write(to: source)
            let imported = try library.prepareImport(audio: source, selection: selection)
            XCTAssertNotEqual(imported, source)
            XCTAssertEqual(imported.deletingLastPathComponent().standardizedFileURL, library.pendingDirectory.standardizedFileURL)
            XCTAssertTrue(imported.lastPathComponent.hasPrefix("Import-"))
            XCTAssertTrue(imported.lastPathComponent.hasSuffix(source.lastPathComponent))
            XCTAssertEqual(imported.pathExtension, "m4a")
            XCTAssertEqual(try Data(contentsOf: source), bytes)
            try FileManager.default.removeItem(at: source)
            let restored = TranscriptionLibrary(directory: library.directory, pendingDirectory: library.pendingDirectory)
            let pending = try XCTUnwrap(restored.pendingTranscription(for: imported))
            XCTAssertEqual(try Data(contentsOf: imported), bytes)
            XCTAssertEqual(pending.selection, selection)
            XCTAssertEqual(pending.origin, .shared)
            XCTAssertEqual(pending.filename, source.lastPathComponent)
            XCTAssertFalse(pending.isRerun)
            XCTAssertNil(pending.localAudioName)
            XCTAssertEqual(SpeechSelection.current, defaults)
            imports.append(imported)
        }
        XCTAssertEqual(Set(library.pendingAudio()), Set(imports))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: library.pendingDirectory.path).count, 4)
    }

    func testImportingTheSameFileAgainCreatesIndependentPendingRecordings() throws {
        let (root, library) = try fixture()
        let source = root.appendingPathComponent("note.wav")
        try Data([1, 2, 3]).write(to: source)
        let selection = SpeechSelection(onDevice: true, model: "turbo", language: "auto", style: .original, customPrompt: "")
        let first = try library.prepareImport(audio: source, selection: selection)
        let second = try library.prepareImport(audio: source, selection: selection)
        XCTAssertNotEqual(first, second)
        XCTAssertNotEqual(TranscriptionLibrary.localID(for: first), TranscriptionLibrary.localID(for: second))
        XCTAssertEqual(library.selection(for: first), selection)
        XCTAssertEqual(library.selection(for: second), selection)
        XCTAssertEqual(Set(library.pendingAudio()), [first, second])
    }

    func testEmptyDirectoryAndOversizedFilesLeaveNoPendingAudioOrMetadata() throws {
        let (root, library) = try fixture()
        let empty = root.appendingPathComponent("empty.m4a")
        let directory = root.appendingPathComponent("directory.m4a", isDirectory: true)
        let oversized = root.appendingPathComponent("oversized.m4a")
        try Data().write(to: empty)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data([1]).write(to: oversized)
        let handle = try FileHandle(forWritingTo: oversized)
        try handle.truncate(atOffset: 52_428_801)
        try handle.close()
        for source in [empty, directory, oversized] {
            XCTAssertThrowsError(try library.prepareImport(audio: source, selection: .current), source.lastPathComponent)
            XCTAssertTrue(library.pendingAudio().isEmpty)
            XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: library.pendingDirectory.path).isEmpty)
        }
    }

    func testUnreadableSourceCopyLeavesNoUntaggedAudioOrMetadata() throws {
        let (root, library) = try fixture()
        let source = root.appendingPathComponent("unreadable.m4a")
        try Data([1, 2, 3]).write(to: source)
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: source.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: source.path) }
        XCTAssertThrowsError(try library.prepareImport(audio: source, selection: .current))
        XCTAssertTrue(library.pendingAudio().isEmpty)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: library.pendingDirectory.path).isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }

    private func fixture() throws -> (root: URL, library: TranscriptionLibrary) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let pending = root.appendingPathComponent("pending", isDirectory: true)
        try FileManager.default.createDirectory(at: pending, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return (root, TranscriptionLibrary(directory: root.appendingPathComponent("library"), pendingDirectory: pending))
    }
}
