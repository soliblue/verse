import Foundation

struct SpeechAPI {
    private struct History: Decodable { let transcriptions: [Transcription] }
    struct Configuration: Decodable { let models: [String] }

    func uploadChunk(_ data: Data, id: String, index: Int, model: String) async throws {
        var parts = URLComponents()
        parts.queryItems = [URLQueryItem(name: "model", value: model)]
        var request = try request("/v1/uploads/\(id)/\(index)" + (parts.string ?? ""))
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        let (body, response) = try await URLSession.shared.upload(for: request, from: data)
        try validate(response, data: body)
    }

    func finishUpload(_ manifest: Data, id: String, filename: String, model: String, language: String, origin: TranscriptionOrigin) async throws -> Transcription {
        var parts = URLComponents()
        parts.queryItems = [URLQueryItem(name: "filename", value: filename), URLQueryItem(name: "model", value: model), URLQueryItem(name: "language", value: language), URLQueryItem(name: "origin", value: origin.rawValue)]
        var request = try request("/v1/uploads/\(id)/finish" + (parts.string ?? ""))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (body, response) = try await URLSession.shared.upload(for: request, from: manifest)
        try validate(response, data: body)
        return try decoder.decode(Transcription.self, from: body)
    }

    func discardUpload(_ id: String) async {
        guard var request = try? request("/v1/uploads/\(id)") else { return }
        request.httpMethod = "DELETE"
        _ = try? await URLSession.shared.data(for: request)
    }

    func history() async throws -> [Transcription] {
        try await decode(History.self, request: request("/v1/transcriptions")).transcriptions
    }

    func transcription(_ id: String) async throws -> Transcription? {
        let (data, response) = try await URLSession.shared.data(for: request("/v1/transcriptions/\(id)"))
        if (response as? HTTPURLResponse)?.statusCode == 404 { return nil }
        try validate(response, data: data)
        return try decoder.decode(Transcription.self, from: data)
    }

    func configuration() async throws -> Configuration {
        try await decode(Configuration.self, request: request("/v1/config"))
    }

    func upload(_ url: URL, selection: SpeechSelection = .current) async throws -> Transcription {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0, size <= 52_428_800 else {
            throw SpeechFailure("Choose an audio file smaller than 50 MB.")
        }
        let identifier = Self.recordingIdentifier(for: url)
        if let identifier, let existing = try await transcription(identifier) { return existing }
        var parts = URLComponents()
        parts.queryItems = [
            URLQueryItem(name: "model", value: selection.model),
            URLQueryItem(name: "language", value: selection.language),
            URLQueryItem(name: "filename", value: url.lastPathComponent),
            URLQueryItem(name: "origin", value: TranscriptionOrigin.pendingAudio(url).rawValue)
        ]
        if let identifier { parts.queryItems?.append(URLQueryItem(name: "upload_id", value: identifier)) }
        var request = try request("/v1/transcriptions" + (parts.string ?? ""))
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await URLSession.shared.upload(for: request, fromFile: url)
        try validate(response, data: data)
        return try decoder.decode(Transcription.self, from: data)
    }

    static func recordingIdentifier(for url: URL) -> String? {
        let name = url.deletingPathExtension().lastPathComponent
        guard let prefix = ["Recording-keyboard-", "Recording-app-", "Recording-"].first(where: { name.hasPrefix($0) }),
              let uuid = UUID(uuidString: String(name.dropFirst(prefix.count))) else { return nil }
        return uuid.uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }

    func delete(_ id: String) async throws {
        var request = try request("/v1/transcriptions/\(id)")
        request.httpMethod = "DELETE"
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response, data: data)
    }

    func audio(_ id: String) async throws -> URL {
        let (url, response) = try await URLSession.shared.download(for: request("/v1/transcriptions/\(id)/audio"))
        try validate(response, data: Data())
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("\(id).audio")
        if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }
        try FileManager.default.moveItem(at: url, to: destination)
        return destination
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    private func request(_ path: String) throws -> URLRequest {
        guard !VerseBridge.token.isEmpty else { throw SpeechFailure("Add your device token in Settings first.") }
        guard let url = URL(string: VerseBridge.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + path),
              url.scheme == "https", url.host != nil else { throw SpeechFailure("The server needs an HTTPS address.") }
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("Bearer \(VerseBridge.token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func decode<T: Decodable>(_ type: T.Type, request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response, data: data)
        return try decoder.decode(type, from: data)
    }

    private func validate(_ response: URLResponse, data: Data) throws {
        guard let response = response as? HTTPURLResponse else { throw SpeechFailure("No response from the server.") }
        guard (200..<300).contains(response.statusCode) else {
            if response.statusCode == 401 { throw SpeechFailure("Your device token was not accepted. Check Settings.") }
            let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            throw SpeechFailure(payload?["error"] as? String ?? "The server returned \(response.statusCode). Please try again.")
        }
    }
}

struct SpeechFailure: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
