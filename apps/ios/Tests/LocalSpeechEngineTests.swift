import CryptoKit
import XCTest
@testable import Verse

@MainActor
final class LocalSpeechEngineTests: XCTestCase {
    func testDownloadedTinyTranscribesReferenceAudio() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let engine = LocalSpeechEngine(directory: folder.appendingPathComponent("Models"))
        defer { engine.cancelDownload() }
        let downloadStart = Date()
        engine.download("tiny")
        let deadline = Date().addingTimeInterval(360)
        while engine.downloadingModelID != nil, Date() < deadline {
            try await Task.sleep(for: .milliseconds(250))
        }
        guard engine.installedModelIDs.contains("tiny") else {
            throw SpeechFailure(engine.error ?? "The explicit Tiny model smoke-test download timed out.")
        }
        let downloadSeconds = Date().timeIntervalSince(downloadStart)
        let source = try XCTUnwrap(URL(string: "https://raw.githubusercontent.com/argmaxinc/argmax-oss-swift/v1.1.0/Tests/WhisperKitTests/Resources/jfk.wav"))
        let (data, response) = try await URLSession.shared.data(from: source)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(digest, "59dfb9a4acb36fe2a2affc14bacbee2920ff435cb13cc314a08c13f66ba7860e")
        let audio = folder.appendingPathComponent("jfk.wav")
        try data.write(to: audio)
        let loadStart = Date()
        try await engine.prepare(model: "tiny")
        let loadSeconds = Date().timeIntervalSince(loadStart)
        let inferenceStart = Date()
        let result = try await engine.transcribe(url: audio, model: "tiny", language: "en")
        let inferenceSeconds = Date().timeIntervalSince(inferenceStart)
        XCTAssertTrue(result.text.lowercased().contains("country"), result.text)
        XCTAssertTrue(result.text.lowercased().contains("americans"), result.text)
        XCTAssertEqual(result.language, "en")
        XCTAssertGreaterThan(result.duration, 10)
        XCTAssertLessThan(result.duration, 12)
        let metrics: [String: Any] = [
            "environment": "iOS Simulator, not iPhone hardware", "model": "tiny",
            "audio_seconds": result.duration, "download_seconds": downloadSeconds,
            "load_seconds": loadSeconds, "inference_seconds": inferenceSeconds
        ]
        let metricsText = try XCTUnwrap(String(data: JSONSerialization.data(withJSONObject: metrics, options: .sortedKeys), encoding: .utf8))
        print("VERSE_LOCAL_MODEL_SMOKE \(metricsText)")
        let attachment = XCTAttachment(string: metricsText)
        attachment.name = "Local speech simulator metrics"
        attachment.lifetime = .keepAlways
        add(attachment)
        try await engine.delete("tiny")
    }

    func testModelCatalogHasDistinctMultilingualChoices() {
        let models = LocalSpeechEngine.modelChoices
        XCTAssertEqual(models.map(\.id), ["tiny", "base", "small", "medium", "large-v3", "turbo"])
        XCTAssertEqual(Set(models.map(\.variant)).count, models.count)
        XCTAssertFalse(models.contains(where: { $0.variant.contains(".en") }))
        XCTAssertEqual(models.first(where: { $0.id == "medium" })?.variant, "openai_whisper-medium")
        XCTAssertEqual(models.first(where: { $0.id == "turbo" })?.variant, "openai_whisper-large-v3-v20240930_626MB")
    }

    func testInitializationDoesNotCreateOrDownloadModels() {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let engine = LocalSpeechEngine(directory: folder)
        XCTAssertTrue(engine.installedModelIDs.isEmpty)
        XCTAssertNil(engine.downloadingModelID)
        XCTAssertEqual(engine.downloadProgress, 0)
        XCTAssertFalse(engine.isBusy)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
    }

    func testMissingModelPreparationFailsWithoutDownloading() async {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let engine = LocalSpeechEngine(directory: folder)
        let result = await Task { try await engine.prepare(model: "medium") }.result
        guard case .failure(let error) = result else { return XCTFail("A missing model must not be downloaded implicitly") }
        XCTAssertTrue(error.localizedDescription.contains("Download"))
        XCTAssertFalse(engine.isBusy)
        XCTAssertNil(engine.downloadingModelID)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
    }

    func testWarmAndInvalidDownloadDoNotStartNetworkWork() {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let engine = LocalSpeechEngine(directory: folder)
        engine.warm("medium")
        engine.download("not-a-model")
        engine.cancelDownload()
        XCTAssertFalse(engine.isBusy)
        XCTAssertNil(engine.downloadingModelID)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
    }

    func testPartialModelAndMissingTokenizerAreNotInstalled() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let model = folder.appendingPathComponent("models/argmaxinc/whisperkit-coreml/openai_whisper-medium")
        let tokenizer = folder.appendingPathComponent("models/openai/whisper-medium")
        for name in ["AudioEncoder.mlmodelc", "TextDecoder.mlmodelc", "MelSpectrogram.mlmodelc"] {
            try FileManager.default.createDirectory(at: model.appendingPathComponent(name), withIntermediateDirectories: true)
        }
        let engine = LocalSpeechEngine(directory: folder)
        XCTAssertTrue(engine.installedModelIDs.isEmpty)
        try Data("complete".utf8).write(to: model.appendingPathComponent(".verse-complete"))
        engine.refreshInstalled()
        XCTAssertTrue(engine.installedModelIDs.isEmpty)
        try FileManager.default.createDirectory(at: tokenizer, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: tokenizer.appendingPathComponent("tokenizer.json"))
        engine.refreshInstalled()
        XCTAssertTrue(engine.installedModelIDs.isEmpty)
        try Data("{}".utf8).write(to: tokenizer.appendingPathComponent("tokenizer_config.json"))
        engine.refreshInstalled()
        XCTAssertEqual(engine.installedModelIDs, ["medium"])
        engine.download("medium")
        XCTAssertNil(engine.downloadingModelID)
    }

    func testMissingModelTranscriptionClearsBusyState() async {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let engine = LocalSpeechEngine(directory: folder)
        let result = await Task { try await engine.transcribe(url: folder.appendingPathComponent("audio.m4a"), model: "medium", language: "auto") }.result
        guard case .failure = result else { return XCTFail("Missing models must fail before opening audio") }
        XCTAssertFalse(engine.isTranscribing)
        XCTAssertFalse(engine.isPreparing)
        XCTAssertNil(engine.downloadingModelID)
    }

    func testOfflineTokenizerHandlesOriginalAndLargeV3SilenceTokens() async throws {
        for largeV3 in [false, true] {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: folder) }
            try tokenizerFixture(at: folder, largeV3: largeV3)
            let tokenizer = try await OfflineSpeechTokenizer(folder: folder)
            XCTAssertEqual(tokenizer.specialTokens.noSpeechToken, largeV3 ? 50363 : 50362)
            XCTAssertEqual(tokenizer.specialTokens.timeTokenBegin, largeV3 ? 50365 : 50364)
            XCTAssertTrue(tokenizer.allLanguageTokens.contains(50259))
            XCTAssertEqual(tokenizer.convertTokenToId("<|endoftext|>"), 50257)
        }
    }

    func testOfflineTokenizerRejectsMissingFilesWithoutCreatingDownloads() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let result = await Task { try await OfflineSpeechTokenizer(folder: folder) }.result
        guard case .failure = result else { return XCTFail("Missing tokenizer files must fail locally") }
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
    }

    private func tokenizerFixture(at folder: URL, largeV3: Bool) throws {
        let offset = largeV3 ? 1 : 0
        let tokens = [
            "<|endoftext|>": 50257, "<|startoftranscript|>": 50258, "<|en|>": 50259,
            "<|translate|>": 50358 + offset, "<|transcribe|>": 50359 + offset,
            "<|startofprev|>": 50361 + offset, largeV3 ? "<|nospeech|>" : "<|nocaptions|>": 50362 + offset,
            "<|notimestamps|>": 50363 + offset, "<|0.00|>": 50364 + offset
        ]
        let added: [[String: Any]] = tokens.map { ["id": $0.value, "content": $0.key, "special": true, "normalized": false, "single_word": false, "lstrip": false, "rstrip": false] }
        let vocabulary = tokens.merging(["a": 0, "Ġ": 220]) { first, _ in first }
        let data: [String: Any] = ["added_tokens": added, "model": ["type": "BPE", "vocab": vocabulary, "merges": [] as [String]]]
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: data).write(to: folder.appendingPathComponent("tokenizer.json"))
        try JSONSerialization.data(withJSONObject: ["tokenizer_class": "WhisperTokenizer"]).write(to: folder.appendingPathComponent("tokenizer_config.json"))
    }
}
