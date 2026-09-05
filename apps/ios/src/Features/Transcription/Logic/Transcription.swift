import Foundation

struct Transcription: Codable, Identifiable, Hashable {
    let id: String
    let filename: String
    let state: String
    let model: String
    let language: String
    let detectedLanguage: String?
    let text: String?
    let durationSeconds: Double?
    let error: String?
    let createdAt: String
    let updatedAt: String

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

    static let preview = Transcription(
        id: "preview", filename: "Recording-demo.m4a", state: "completed", model: "medium",
        language: "auto", detectedLanguage: "en",
        text: "Hey, I'm on my way. Let's meet outside in ten minutes.",
        durationSeconds: 6, error: nil, createdAt: "2026-09-05T09:00:00Z", updatedAt: "2026-09-05T09:00:00Z"
    )
}
