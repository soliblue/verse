import Foundation

@MainActor
final class APIClient {
    private let configuration: ServerConfiguration
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(configuration: ServerConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    nonisolated deinit {}

    func get<Response: Decodable>(_ path: String, as type: Response.Type) async -> Response? {
        guard let data = await send(path: path, method: "GET") else { return nil }
        return try? decoder.decode(type, from: data)
    }

    func post<Body: Encodable, Response: Decodable>(
        _ path: String,
        body: Body,
        as type: Response.Type
    ) async -> Response? {
        guard
            let payload = try? encoder.encode(body),
            let data = await send(path: path, method: "POST", payload: payload)
        else { return nil }
        return try? decoder.decode(type, from: data)
    }

    func put<Body: Encodable, Response: Decodable>(
        _ path: String,
        body: Body,
        as type: Response.Type
    ) async -> Response? {
        guard
            let payload = try? encoder.encode(body),
            let data = await send(path: path, method: "PUT", payload: payload)
        else { return nil }
        return try? decoder.decode(type, from: data)
    }

    func send(path: String, method: String, payload: Data? = nil) async -> Data? {
        switch await sendResult(path: path, method: method, payload: payload) {
        case .success(let data): return data
        case .transportFailure, .httpFailure(_): return nil
        }
    }

    func sendResult(
        path: String,
        method: String,
        payload: Data? = nil,
        idempotencyKey: String? = nil
    ) async -> HTTPResult {
        guard let base = configuration.serverURL else { return .transportFailure }
        var request = URLRequest(url: base.appending(path: path), timeoutInterval: 20)
        request.httpMethod = method
        request.httpBody = payload
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if payload != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if !configuration.deviceSecret.isEmpty {
            request.setValue("Bearer \(configuration.deviceSecret)", forHTTPHeaderField: "Authorization")
        }
        if let idempotencyKey {
            request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        }
        guard
            let (data, response) = try? await session.data(for: request),
            let http = response as? HTTPURLResponse
        else { return .transportFailure }
        return 200..<300 ~= http.statusCode ? .success(data) : .httpFailure(http.statusCode)
    }

    func data(from url: URL) async -> Data? {
        guard let serverURL = configuration.serverURL, sameOrigin(url, serverURL) else {
            return nil
        }
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("image/*", forHTTPHeaderField: "Accept")
        if !configuration.deviceSecret.isEmpty {
            request.setValue("Bearer \(configuration.deviceSecret)", forHTTPHeaderField: "Authorization")
        }
        guard
            let (data, response) = try? await session.data(for: request),
            let http = response as? HTTPURLResponse,
            200..<300 ~= http.statusCode,
            http.mimeType?.hasPrefix("image/") == true,
            data.count <= 10_485_760
        else { return nil }
        return data
    }

    private func sameOrigin(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.scheme?.lowercased() == rhs.scheme?.lowercased()
            && lhs.host?.lowercased() == rhs.host?.lowercased()
            && originPort(lhs) == originPort(rhs)
    }

    private func originPort(_ url: URL) -> Int? {
        if let port = url.port { return port }
        switch url.scheme?.lowercased() {
        case "http": return 80
        case "https": return 443
        default: return nil
        }
    }
}
