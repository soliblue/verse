import Foundation

struct SpeechSelection: Codable, Equatable, Sendable {
    var onDevice: Bool
    var model: String
    var language: String
    var style: TranscriptStyle
    var customPrompt: String

    static var current: Self {
        Self(onDevice: VerseBridge.onDeviceTranscriptionEnabled,
             model: VerseBridge.onDeviceTranscriptionEnabled ? VerseBridge.localModel : VerseBridge.model,
             language: VerseBridge.language,
             style: TranscriptStyle(rawValue: VerseBridge.writingStyle) ?? .original,
             customPrompt: VerseBridge.customWritingPrompt)
    }
}

#if !VERSE_WIDGET
@MainActor
enum TranscriptDelivery {
    static func prepare(id: String, text: String, language: String?) async -> TranscriptRewriteResult {
        guard !VerseBridge.isDeleted(id) else { return .original(text, style: .original, fallback: .cancelled) }
        if let cached = VerseBridge.rewriteResult(for: id), cached.original == text { return cached }
        let options = VerseBridge.options(for: id)
        guard let options else { return .original(text, style: .original) }
        let deadline = Date().addingTimeInterval(18)
        var owner = VerseBridge.claimRewrite(for: id)
        while owner == nil {
            guard !VerseBridge.isDeleted(id) else { return .original(text, style: options.style, fallback: .cancelled) }
            if let cached = VerseBridge.rewriteResult(for: id), cached.original == text { return cached }
            guard !Task.isCancelled else { return .original(text, style: options.style, fallback: .cancelled) }
            guard Date() < deadline else {
                return VerseBridge.saveRewrite(.original(text, style: options.style, fallback: .timedOut), for: id)
            }
            try? await Task.sleep(for: .milliseconds(250))
            owner = VerseBridge.claimRewrite(for: id)
        }
        defer { if let owner { VerseBridge.releaseRewrite(for: id, owner: owner) } }
        if let cached = VerseBridge.rewriteResult(for: id), cached.original == text { return cached }
        let result = await AppleWritingService.shared.rewrite(
            text: text, language: language,
            style: options.style, customPrompt: options.customPrompt
        )
        guard !Task.isCancelled else { return result }
        return VerseBridge.saveRewrite(result, for: id)
    }
}
#endif
