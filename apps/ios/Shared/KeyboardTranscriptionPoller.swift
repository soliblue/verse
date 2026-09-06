#if !VERSE_WIDGET
import Foundation

@MainActor
final class KeyboardTranscriptionPoller {
    private struct Job: Decodable {
        let id: String
        let state: String
        let text: String?
        let error: String?
        let detectedLanguage: String?

        enum CodingKeys: String, CodingKey {
            case id, state, text, error
            case detectedLanguage = "detected_language"
        }
    }

    private var task: Task<Void, Never>?
    private var lastPoll = Date.distantPast
    private var generation = 0

    nonisolated deinit {}

    func poll(state: [String: String]) {
        guard task == nil, Date().timeIntervalSince(lastPoll) >= 0.75 else { return }
        let id = state["pendingJobID"] ?? ""
        let token = state["token"] ?? ""
        guard !id.isEmpty, !id.hasPrefix("local-"), !token.isEmpty,
              let base = URL(string: state["baseURL"] ?? VerseBridge.defaultBaseURL), base.scheme == "https", base.host != nil else { return }
        lastPoll = Date()
        generation += 1
        let currentGeneration = generation
        task = Task { [weak self] in
            defer { if self?.generation == currentGeneration { self?.task = nil } }
            var request = URLRequest(url: base.appendingPathComponent("v1/transcriptions").appendingPathComponent(id))
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 15
            if let (data, response) = try? await URLSession.shared.data(for: request),
               !Task.isCancelled,
               let response = response as? HTTPURLResponse {
                let statusCode = response.statusCode
                let job = statusCode == 200 ? (try? JSONDecoder().decode(Job.self, from: data)) : nil
                guard statusCode == 401 || (statusCode == 200 && job?.id == id && (job?.state == "completed" || job?.state == "failed")) else { return }
                let state = job?.state
                let output: String?
                if job?.state == "completed" {
                    output = await TranscriptDelivery.prepare(id: id, text: job?.text ?? "", language: job?.detectedLanguage).text
                } else { output = job?.text }
                guard !Task.isCancelled else { return }
                let error = job?.error
                let publication = Task.detached(priority: .userInitiated) {
                    VerseBridge.publishTranscriptionResult(id: id, statusCode: statusCode, state: state, text: output, error: error)
                }
                await withTaskCancellationHandler(operation: { await publication.value }, onCancel: { publication.cancel() })
            }
        }
    }

    func cancel() {
        generation += 1
        task?.cancel()
        task = nil
    }
}
#endif
