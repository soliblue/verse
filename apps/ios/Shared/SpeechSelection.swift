import Foundation

struct SpeechModelChoice: Identifiable, Hashable, Sendable {
    let onDevice: Bool
    let model: String

    var id: String { (onDevice ? "local." : "cloud.") + model }
    var title: String { (onDevice ? "Local " : "Cloud ") + name }
    var name: String {
        switch model {
        case "large-v3": return "Large v3"
        case "turbo": return "Large v3 Turbo"
        default: return model.capitalized
        }
    }

    static let all = ["tiny", "base", "small", "medium", "large-v3", "turbo"].map {
        Self(onDevice: true, model: $0)
    } + ["small", "medium", "large-v3"].map {
        Self(onDevice: false, model: $0)
    }
}

struct SpeechSelection: Codable, Equatable, Sendable {
    var onDevice: Bool
    var model: String
    var language: String
    var style: TranscriptStyle
    var customPrompt: String

    var modelChoice: SpeechModelChoice { .init(onDevice: onDevice, model: model) }

    func replacingModel(_ choice: SpeechModelChoice) -> Self {
        var result = self
        result.onDevice = choice.onDevice
        result.model = choice.model
        return result
    }

    static var current: Self {
        Self(onDevice: VerseBridge.onDeviceTranscriptionEnabled,
             model: VerseBridge.onDeviceTranscriptionEnabled ? VerseBridge.localModel : VerseBridge.model,
             language: VerseBridge.language,
             style: VerseBridge.writingEnabled ? TranscriptStyle(rawValue: VerseBridge.writingStyle) ?? .original : .original,
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
