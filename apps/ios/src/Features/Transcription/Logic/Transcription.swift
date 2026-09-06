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
    var filename: String
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
    var recordingID: String? = nil
    var customPrompt: String? = nil

    var isLocal: Bool { engine == "on-device" }
    var recordingKey: String { recordingID ?? id }
    var modelLabel: String {
        let names = ["tiny": "Tiny", "base": "Base", "small": "Small", "medium": "Medium", "large-v3": "Large v3", "turbo": "Large v3 Turbo", "large-v3-turbo": "Large v3 Turbo"]
        return "\(isLocal ? "Local" : "Cloud") · \(names[model] ?? model)"
    }
    var selection: SpeechSelection {
        SpeechSelection(onDevice: isLocal, model: model, language: language,
                        style: TranscriptStyle(rawValue: writingStyle ?? "original") ?? .original,
                        customPrompt: customPrompt ?? "")
    }
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

    static func recordings(from items: [Self]) -> [Self] {
        var seen = Set<String>()
        return items.sorted { $0.date == $1.date ? $0.id > $1.id : $0.date > $1.date }
            .filter { seen.insert($0.recordingKey).inserted }
    }

    static func versions(for id: String, in items: [Self]) -> [Self] {
        let key = items.first { $0.id == id }?.recordingKey ?? id
        return items.filter { $0.recordingKey == key }
            .sorted { $0.date == $1.date ? $0.id > $1.id : $0.date > $1.date }
    }

    static let preview = Transcription(
        id: "preview", filename: "Recording-demo.m4a", state: "completed", model: "medium",
        language: "auto", detectedLanguage: "en",
        text: "Hey, I'm on my way. Let's meet outside in ten minutes.",
        durationSeconds: 6, error: nil, createdAt: "2026-09-05T09:00:00Z", updatedAt: "2026-09-05T09:00:00Z",
        origin: .app, engine: "on-device"
    )

    static let previewVersions = [preview, Transcription(
        id: "preview-cloud-small", filename: preview.filename, state: "completed", model: "small",
        language: "auto", detectedLanguage: "en", text: "Hey, I'm on my way. Meet me outside in ten minutes.",
        durationSeconds: 6, error: nil, createdAt: "2026-09-05T09:01:00Z", updatedAt: "2026-09-05T09:01:00Z",
        origin: .app, recordingID: preview.id
    )]

    static var previewHistory: [Self] {
        let messages = [
            "I'll be there in ten minutes. See you outside.",
            "That sounds good. Let's talk about it tomorrow.",
            "Could you send me the address when you have a moment?",
            "I just had an idea for the weekend. Call me when you're free."
        ]
        return (0..<12).map { index in
            let date = "2026-09-06T\(String(format: "%02d", 20 - index)):00:00Z"
            return Self(id: "preview-history-\(index)", filename: "Recording-demo-\(index).m4a", state: "completed",
                        model: index.isMultiple(of: 2) ? "medium" : "small", language: "auto", detectedLanguage: "en",
                        text: messages[index % messages.count], durationSeconds: Double(index + 4), error: nil,
                        createdAt: date, updatedAt: date, origin: .app,
                        engine: index.isMultiple(of: 2) ? "on-device" : nil)
        }
    }
}
