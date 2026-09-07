import AVFoundation
import XCTest
@testable import Verse

@MainActor
final class TranscriptionTests: XCTestCase {
    func testServerPayloadDecodes() throws {
        let data = Data("""
        {"id":"abc","filename":"voice.m4a","state":"completed","model":"small","language":"auto","detected_language":"en","text":"Hello","duration_seconds":2.5,"error":null,"created_at":"2026-09-05T09:00:00+00:00","updated_at":"2026-09-05T09:00:00+00:00"}
        """.utf8)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let item = try decoder.decode(Transcription.self, from: data)
        XCTAssertEqual(item.text, "Hello")
        XCTAssertEqual(item.detectedLanguage, "en")
        XCTAssertNil(item.origin)
        XCTAssertEqual(item.recordingKey, "abc")
        XCTAssertEqual(item.modelLabel, "Cloud · Small")
        XCTAssertEqual(item.selection.style, .original)
        XCTAssertNil(item.completionNotificationBody(enabled: true, appIsActive: false))
        XCTAssertFalse(item.isPending)
        XCTAssertGreaterThan(item.date.timeIntervalSince1970, 0)
    }

    func testCaptureProducesPlayableCompressedAudio() throws {
        let writer = CaptureWriter()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        defer { try? FileManager.default.removeItem(at: url) }
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 48_000))
        buffer.frameLength = 48_000
        let samples = try XCTUnwrap(buffer.floatChannelData?[0])
        for frame in 0..<48_000 { samples[frame] = Float(sin(Double(frame) * 440 * 2 * .pi / 48_000)) * 0.2 }
        try writer.begin(url: url, format: format)
        for _ in 0..<10 { writer.append(buffer) }
        XCTAssertGreaterThan(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0, 32 * 1024)
        try writer.finish()
        let file = try AVAudioFile(forReading: url)
        XCTAssertEqual(file.fileFormat.streamDescription.pointee.mFormatID, kAudioFormatMPEG4AAC)
        XCTAssertGreaterThan(file.length, 450_000)
        XCTAssertLessThan(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max, 250_000)
    }

    func testRecordingUploadIdentifierSurvivesRetry() {
        let id = "ABCD1234-5678-4ABC-9123-123456789ABC"
        let url = URL(fileURLWithPath: "Recording-\(id).m4a")
        XCTAssertEqual(SpeechAPI.recordingIdentifier(for: url), "abcd123456784abc9123123456789abc")
        let restored = URL(fileURLWithPath: "PendingAudio/Recording-\(id).m4a")
        XCTAssertEqual(SpeechAPI.recordingIdentifier(for: restored), SpeechAPI.recordingIdentifier(for: url))
        XCTAssertNil(SpeechAPI.recordingIdentifier(for: URL(fileURLWithPath: "Imported.m4a")))
        XCTAssertNil(SpeechAPI.recordingIdentifier(for: URL(fileURLWithPath: "Recording-invalid.m4a")))
        let rerun = URL(fileURLWithPath: "PendingAudio/Rerun-\(id).m4a")
        XCTAssertEqual(SpeechAPI.recordingIdentifier(for: rerun), "abcd123456784abc9123123456789abc")
    }

    func testRecordingVersionsRemainGroupedAndKeepTheirOwnModelAndOriginal() throws {
        let original = notificationItem(origin: .app)
        var local = Transcription(id: "local-version", filename: original.filename, state: "completed", model: "turbo",
                                  language: "ar", detectedLanguage: "ar", text: "Original words", durationSeconds: 4,
                                  error: nil, createdAt: "2026-09-06T10:00:00Z", updatedAt: "2026-09-06T10:00:00Z",
                                  origin: .app, engine: "on-device", recordingID: original.id,
                                  customPrompt: "Keep it informal.")
        local = local.applying(.init(original: "Original words", text: "Casual words", style: .custom, fallback: nil))
        let other = Transcription.preview
        let restored = try JSONDecoder().decode([Transcription].self, from: JSONEncoder().encode([original, local, other]))
        let recordings = Transcription.recordings(from: restored)
        XCTAssertEqual(recordings.map(\.id), [local.id, other.id])
        XCTAssertEqual(Transcription.versions(for: original.id, in: restored).map(\.id), [local.id, original.id])
        XCTAssertEqual(Transcription.versions(for: local.id, in: restored).map(\.id), [local.id, original.id])
        XCTAssertEqual(local.modelLabel, "Local · Large v3 Turbo")
        XCTAssertEqual(local.compactModelLabel, "Local Turbo")
        XCTAssertEqual(local.originalText, "Original words")
        XCTAssertEqual(local.selection, SpeechSelection(onDevice: true, model: "turbo", language: "ar", style: .custom, customPrompt: "Keep it informal."))
        XCTAssertEqual(original.modelLabel, "Cloud · Medium")
        XCTAssertEqual(original.text, "Hello, see you at eight.\nBis später!")
    }

    func testPreferredVersionChangesContentWithoutMovingRecordingAnchors() throws {
        let items = Transcription.previewVersions + Transcription.previewHistory.prefix(2)
        let anchors = Transcription.recordings(from: items)
        let selected = [Transcription.preview.recordingKey: Transcription.preview.id]
        let displayed = anchors.compactMap {
            Transcription.preferredVersion(for: $0.recordingKey, in: items, selectedVersions: selected)
        }
        XCTAssertEqual(displayed.map(\.recordingKey), anchors.map(\.recordingKey))
        XCTAssertEqual(displayed.last?.id, Transcription.preview.id)
        XCTAssertEqual(anchors.last?.id, "preview-cloud-small")
        XCTAssertEqual(Transcription.recordings(from: items).map(\.date), anchors.map(\.date))
        XCTAssertEqual(Transcription.preferredVersion(for: "preview-cloud-small", in: items, selectedVersions: selected)?.id,
                       Transcription.preview.id)
    }

    func testMissingDeletedAndUnrelatedVersionSelectionsUseGroupFallback() {
        let items = Transcription.previewVersions + Transcription.previewHistory.prefix(1)
        for selected in [[:], ["preview": "missing"], ["preview": "preview-history-0"]] {
            XCTAssertEqual(Transcription.preferredVersion(for: "preview", in: items, selectedVersions: selected)?.id,
                           "preview-cloud-small")
        }
        let remaining = items.filter { $0.id != "preview" }
        XCTAssertEqual(Transcription.preferredVersion(for: "preview", in: remaining,
                                                    selectedVersions: ["preview": "preview"])?.id, "preview-cloud-small")
        XCTAssertNil(Transcription.preferredVersion(for: "deleted-recording", in: items, selectedVersions: [:]))
        XCTAssertNil(Transcription.preferredVersion(for: "preview", in: [], selectedVersions: ["preview": "preview"]))
    }

    func testCompactMetadataUsesRequestedLanguageNotDetection() {
        var item = Transcription.preview
        XCTAssertEqual(item.compactModelLabel, "Local Medium")
        XCTAssertEqual(item.languageLabel, "AUTO")
        item.language = " ar "
        XCTAssertEqual(item.languageLabel, "AR")
        XCTAssertEqual(item.detectedLanguage, "en")
        item.language = ""
        XCTAssertEqual(item.languageLabel, "AUTO")
        item.language = "Auto"
        XCTAssertEqual(item.languageLabel, "AUTO")
        XCTAssertEqual(Transcription.previewVersions.last?.compactModelLabel, "Cloud Small")
    }

    func testPendingOriginAndIdentifierSurviveRecordingRetry() {
        let id = "ABCD1234-5678-4ABC-9123-123456789ABC"
        for origin in [TranscriptionOrigin.app, .keyboard] {
            let name = "Recording-\(origin.rawValue)-\(id).m4a"
            let url = URL(fileURLWithPath: "PendingAudio/\(name)")
            let restored = URL(fileURLWithPath: url.path)
            XCTAssertEqual(TranscriptionOrigin.pendingAudio(restored), origin)
            XCTAssertEqual(SpeechAPI.recordingIdentifier(for: restored), "abcd123456784abc9123123456789abc")
        }
        XCTAssertEqual(TranscriptionOrigin.pendingAudio(URL(fileURLWithPath: "Import-\(id)-voice.m4a")), .shared)
        XCTAssertEqual(TranscriptionOrigin.pendingAudio(URL(fileURLWithPath: "Recording-\(id).m4a")), .unknown)
        XCTAssertEqual(TranscriptionOrigin.pendingAudio(URL(fileURLWithPath: "unknown.m4a")), .unknown)
    }

    func testCompletionNotificationsContainTranscriptionForAppAndSharedAudio() throws {
        for origin in [TranscriptionOrigin.app, .shared] {
            let item = notificationItem(origin: origin)
            let restored = try JSONDecoder().decode(Transcription.self, from: JSONEncoder().encode(item))
            XCTAssertEqual(restored.origin, origin)
            XCTAssertEqual(restored.completionNotificationBody(enabled: true, appIsActive: false), "Hello, see you at eight.\nBis später!")
        }
    }

    func testKeyboardAndUnknownJobsNeverProduceCompletionNotifications() throws {
        let origins: [TranscriptionOrigin?] = [.keyboard, .unknown, nil]
        for origin in origins {
            let item = notificationItem(origin: origin)
            let restored = try JSONDecoder().decode(Transcription.self, from: JSONEncoder().encode(item))
            XCTAssertNil(restored.completionNotificationBody(enabled: true, appIsActive: false))
        }
    }

    func testCompletionNotificationsRespectPreferenceForegroundAndContent() {
        let item = notificationItem(origin: .app)
        XCTAssertNil(item.completionNotificationBody(enabled: false, appIsActive: false))
        XCTAssertNil(item.completionNotificationBody(enabled: true, appIsActive: true))
        for state in ["queued", "transcribing", "failed"] {
            XCTAssertNil(notificationItem(origin: .shared, state: state).completionNotificationBody(enabled: true, appIsActive: false))
        }
        let transcripts: [String?] = [nil, "", " \n "]
        for text in transcripts {
            XCTAssertNil(notificationItem(origin: .shared, text: text).completionNotificationBody(enabled: true, appIsActive: false))
        }
    }

    private func notificationItem(origin: TranscriptionOrigin?, state: String = "completed", text: String? = "Hello, see you at eight.\nBis später!") -> Transcription {
        Transcription(id: "notification", filename: "Recording-test.m4a", state: state, model: "medium",
                      language: "auto", detectedLanguage: "en", text: text, durationSeconds: 4, error: nil,
                      createdAt: "2026-09-06T09:00:00Z", updatedAt: "2026-09-06T09:00:00Z", origin: origin)
    }
}
