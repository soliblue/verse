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

    func poll() {
        guard task == nil, Date().timeIntervalSince(lastPoll) >= 2 else { return }
        let id = VerseBridge.pendingJobID
        guard !id.isEmpty, !VerseBridge.token.isEmpty,
              let base = URL(string: VerseBridge.baseURL), base.scheme == "https", base.host != nil else { return }
        lastPoll = Date()
        task = Task { [weak self] in
            defer { self?.task = nil }
            var request = URLRequest(url: base.appendingPathComponent("v1/transcriptions").appendingPathComponent(id))
            request.setValue("Bearer \(VerseBridge.token)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 15
            let result = await Task { try await URLSession.shared.data(for: request) }.result
            guard !Task.isCancelled, VerseBridge.pendingJobID == id else { return }
            if case .success(let (data, response)) = result,
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
        task?.cancel()
        task = nil
    }
}
