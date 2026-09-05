#if !VERSE_WIDGET
import Foundation

@MainActor
final class KeyboardTranscriptionPoller {
    private struct Job: Decodable {
        let id: String
        let state: String
        let text: String?
        let error: String?
    }

    private var task: Task<Void, Never>?
    private var lastPoll = Date.distantPast
    private var generation = 0

    func poll() {
        guard task == nil, Date().timeIntervalSince(lastPoll) >= 0.75 else { return }
        let id = VerseBridge.pendingJobID
        guard !id.isEmpty, !VerseBridge.token.isEmpty,
              let base = URL(string: VerseBridge.baseURL), base.scheme == "https", base.host != nil else { return }
        lastPoll = Date()
        generation += 1
        let currentGeneration = generation
        task = Task { [weak self] in
            defer { if self?.generation == currentGeneration { self?.task = nil } }
            var request = URLRequest(url: base.appendingPathComponent("v1/transcriptions").appendingPathComponent(id))
            request.setValue("Bearer \(VerseBridge.token)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 15
            if let (data, response) = try? await URLSession.shared.data(for: request),
               !Task.isCancelled, VerseBridge.pendingJobID == id,
               let response = response as? HTTPURLResponse {
                if response.statusCode == 401 {
                    VerseBridge.errorText = "Your device token was not accepted. Check Verse Settings."
                } else if response.statusCode == 200,
                          let job = try? JSONDecoder().decode(Job.self, from: data), job.id == id {
                    if job.state == "completed" {
                        VerseBridge.transcriptText = job.text ?? ""
                        VerseBridge.transcriptID = id
                        VerseBridge.errorText = ""
                        if VerseBridge.pendingInsertionJobID == id {
                            VerseBridge.insertionTranscriptID = id
                            VerseBridge.insertionReadyAt = Date().timeIntervalSince1970
                            VerseBridge.pendingInsertionJobID = ""
                        }
                        VerseBridge.pendingJobID = ""
                        VerseBridge.statusText = ""
                    } else if job.state == "failed" {
                        VerseBridge.errorText = job.error ?? "Transcription failed. Try again in Verse."
                        VerseBridge.pendingJobID = ""
                        VerseBridge.pendingInsertionJobID = ""
                        VerseBridge.statusText = ""
                    }
                }
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
