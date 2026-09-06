import Foundation

enum TranscriptionOrigin: String, Codable {
    case app, shared, keyboard, unknown

    static func pendingAudio(_ url: URL) -> Self {
        let filename = url.lastPathComponent
        if filename.hasPrefix("Recording-keyboard-") { return .keyboard }
        if filename.hasPrefix("Recording-app-") { return .app }
        if filename.hasPrefix("Import-") { return .shared }
        return .unknown
    }
}

struct Transcription: Codable, Identifiable, Hashable {
    let id: String
    let filename: String
    let state: String
    let model: String
    let language: String
    let detectedLanguage: String?
    var text: String?
    let durationSeconds: Double?
    let error: String?
    let createdAt: String
    let updatedAt: String
    var origin: TranscriptionOrigin? = nil
    var engine: String? = nil
    var localAudioName: String? = nil
    var originalText: String? = nil
    var writingStyle: String? = nil
    var writingFallback: String? = nil

    var isLocal: Bool { engine == "on-device" }
    var hasRewrite: Bool { originalText != nil && originalText != text }
    var isPending: Bool { state == "queued" || state == "transcribing" }
    var title: String {
        if let text, !text.isEmpty { return String(text.prefix(100)) }
        return filename.hasPrefix("Recording-") ? "Voice recording" : filename
    }
    var date: Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: createdAt) ?? ISO8601DateFormatter().date(from: createdAt) ?? .distantPast
    }

    func applying(_ result: TranscriptRewriteResult) -> Self {
        var copy = self
        copy.text = result.text
        copy.originalText = result.original
        copy.writingStyle = result.style.rawValue
        copy.writingFallback = result.fallback?.rawValue
        return copy
    }

    func completionNotificationBody(enabled: Bool, appIsActive: Bool) -> String? {
        guard enabled, !appIsActive, state == "completed", origin == .app || origin == .shared,
              let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return text
    }

    static let preview = Transcription(
        id: "preview", filename: "Recording-demo.m4a", state: "completed", model: "medium",
        language: "auto", detectedLanguage: "en",
        text: "Hey, I'm on my way. Let's meet outside in ten minutes.",
        durationSeconds: 6, error: nil, createdAt: "2026-09-05T09:00:00Z", updatedAt: "2026-09-05T09:00:00Z"
    )
}
