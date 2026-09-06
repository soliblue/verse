#if !VERSE_WIDGET
import Foundation
import FoundationModels
import NaturalLanguage
import Observation

@MainActor
@Observable
final class AppleWritingService {
    static let shared = AppleWritingService()
    private(set) var availability: AppleWritingAvailability = .unavailable
    private var preparedSession: AnyObject?

    init() {
        refreshAvailability()
    }

    @discardableResult
    func refreshAvailability() -> AppleWritingAvailability {
        #if DEBUG
        if let override = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--writing-availability=") }),
           let value = AppleWritingAvailability(rawValue: String(override.dropFirst("--writing-availability=".count))) {
            availability = value
            return value
        }
        #endif
        guard #available(iOS 26.0, *) else {
            availability = .requiresUpdate
            return availability
        }
        switch SystemLanguageModel.default.availability {
        case .available: availability = .available
        case .unavailable(.deviceNotEligible): availability = .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled): availability = .appleIntelligenceNotEnabled
        case .unavailable(.modelNotReady): availability = .modelNotReady
        case .unavailable: availability = .unavailable
        @unknown default: availability = .unavailable
        }
        if !availability.isAvailable { preparedSession = nil }
        return availability
    }

    func prewarm(style: TranscriptStyle, customPrompt: String = "") {
        guard let instructions = TranscriptWritingPolicy.instructions(style: style, customPrompt: customPrompt),
              #available(iOS 26.0, *), refreshAvailability().isAvailable else {
            preparedSession = nil
            return
        }
        #if DEBUG
        guard !ProcessInfo.processInfo.arguments.contains("--ui-testing") else { return }
        #endif
        let prepared = WritingSession(instructions: instructions)
        prepared.session.prewarm()
        preparedSession = prepared
    }

    func rewrite(text: String, language: String? = nil, style: TranscriptStyle, customPrompt: String = "") async -> TranscriptRewriteResult {
        guard style != .original, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .original(text, style: style)
        }
        guard !Task.isCancelled else { return .original(text, style: style, fallback: .cancelled) }
        guard let instructions = TranscriptWritingPolicy.instructions(style: style, customPrompt: customPrompt) else {
            return .original(text, style: style, fallback: .emptyPrompt)
        }
        guard text.utf8.count <= TranscriptWritingPolicy.maximumInputBytes else {
            return .original(text, style: style, fallback: .tooLong)
        }
        guard #available(iOS 26.0, *), refreshAvailability().isAvailable else {
            return .original(text, style: style, fallback: .unavailable)
        }
        #if DEBUG
        guard !ProcessInfo.processInfo.arguments.contains("--ui-testing") else {
            return .original(text, style: style, fallback: .unavailable)
        }
        #endif
        let model = SystemLanguageModel.default
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let code = language.flatMap { $0.isEmpty || $0 == "auto" ? nil : $0 } ?? recognizer.dominantLanguage?.rawValue
        guard let code, model.supportsLocale(Locale(identifier: code)),
              !TranscriptWritingPolicy.containsArabic(text) || model.supportsLocale(Locale(identifier: "ar")) else {
            return .original(text, style: style, fallback: .unsupportedLanguage)
        }
        let prepared = (preparedSession as? WritingSession).flatMap { $0.instructions == instructions ? $0 : nil }
            ?? WritingSession(instructions: instructions)
        preparedSession = nil
        let prompt = "Transcript to edit:\n" + text
        let options = GenerationOptions(temperature: 0, maximumResponseTokens: min(1_800, max(128, text.utf8.count / 2 + 128)))
        let request = Task { try await prepared.session.respond(to: prompt, options: options).content }
        var timedOut = false
        let timeout = Task {
            try? await Task.sleep(for: .seconds(15))
            guard !Task.isCancelled else { return }
            timedOut = true
            request.cancel()
        }
        defer { timeout.cancel() }
        let result = await withTaskCancellationHandler(operation: { await request.result }, onCancel: { request.cancel() })
        guard !Task.isCancelled else { return .original(text, style: style, fallback: .cancelled) }
        guard !timedOut else { return .original(text, style: style, fallback: .timedOut) }
        guard case .success(let response) = result else {
            refreshAvailability()
            return .original(text, style: style, fallback: .failed)
        }
        guard let rewritten = TranscriptWritingPolicy.validatedText(response, original: text) else {
            return .original(text, style: style, fallback: .invalidResponse)
        }
        return TranscriptRewriteResult(original: text, text: rewritten, style: style, fallback: nil)
    }
}

@available(iOS 26.0, *)
@MainActor
private final class WritingSession {
    let instructions: String
    let session: LanguageModelSession

    init(instructions: String) {
        self.instructions = instructions
        session = LanguageModelSession(instructions: instructions)
    }
}
#endif
