import Foundation

struct SpeechAPI {
    private struct History: Decodable { let transcriptions: [Transcription] }
    struct Configuration: Decodable { let models: [String] }

    func history() async throws -> [Transcription] {
        try await decode(History.self, request: request("/v1/transcriptions")).transcriptions
    }

    func configuration() async throws -> Configuration {
        try await decode(Configuration.self, request: request("/v1/config"))
    }

    func upload(_ url: URL) async throws -> Transcription {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0, size <= 52_428_800 else {
            throw SpeechFailure("Choose an audio file smaller than 50 MB.")
        }
        var parts = URLComponents()
        parts.queryItems = [
            URLQueryItem(name: "model", value: VerseBridge.model),
            URLQueryItem(name: "language", value: VerseBridge.language),
            URLQueryItem(name: "filename", value: url.lastPathComponent)
        ]
        var request = try request("/v1/transcriptions" + (parts.string ?? ""))
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await URLSession.shared.upload(for: request, fromFile: url)
        try validate(response, data: data)
        return try decoder.decode(Transcription.self, from: data)
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
