import CryptoKit
import Foundation

@MainActor
final class RecordingUpload {
    let url: URL
    private let id: String
    private let api = SpeechAPI()
    private let model = VerseBridge.model
    private let language = VerseBridge.language
    private let chunkSize = 32 * 1024
    private var hashes: [Int: String] = [:]
    private var task: Task<Void, Error>?
    private var manifest: Data?

    init(url: URL) {
        self.url = url
        id = SpeechAPI.recordingIdentifier(for: url) ?? UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        task = Task { [weak self] in
            while !Task.isCancelled {
                try await Task.sleep(for: .seconds(1))
                guard let self else { return }
                try await self.sendAvailable()
            }
        }
    }

    func finish() async throws -> Transcription? {
        if let manifest { return try await submit(manifest) }
        task?.cancel()
        let result = await task?.result
        task = nil
        if let result, case .failure(let error) = result, !(error is CancellationError), (error as NSError).code != NSURLErrorCancelled {
            await api.discardUpload(id)
            return nil
        }
        let prepared = await Task { try await prepare() }.result
        guard case .success(let manifest) = prepared else {
            await api.discardUpload(id)
            return nil
        }
        self.manifest = manifest
        return try await submit(manifest)
    }

    func cancel() {
        task?.cancel()
        task = nil
        let id = id
        let api = api
        Task { await api.discardUpload(id) }
    }

    private func submit(_ manifest: Data) async throws -> Transcription {
        let result = await Task { try await api.finishUpload(manifest, id: id, filename: url.lastPathComponent, model: model, language: language) }.result
        if case .success(let item) = result { return item }
        if let item = try await api.transcription(id) { return item }
        return try result.get()
    }

    private func sendAvailable() async throws {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let size = try handle.seekToEnd()
        guard size <= 52_428_800 else { throw SpeechFailure("Recording is too large.") }
        for index in 0..<(Int(size) / chunkSize) where hashes[index] == nil {
            try Task.checkCancellation()
            try handle.seek(toOffset: UInt64(index * chunkSize))
            let data = try handle.read(upToCount: chunkSize) ?? Data()
            guard data.count == chunkSize else { return }
            try await api.uploadChunk(data, id: id, index: index, model: model)
            hashes[index] = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        }
    }

    private func prepare() async throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let size = try handle.seekToEnd()
        guard size > 0, size <= 52_428_800 else { throw SpeechFailure("Recording is too large or empty.") }
        try handle.seek(toOffset: 0)
        var checksum = SHA256()
        var finalHashes: [String] = []
        while let data = try handle.read(upToCount: chunkSize), !data.isEmpty {
            checksum.update(data: data)
            let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            let index = finalHashes.count
            if hashes[index] != hash { try await api.uploadChunk(data, id: id, index: index, model: model) }
            finalHashes.append(hash)
        }
        let digest = checksum.finalize().map { String(format: "%02x", $0) }.joined()
        return try JSONSerialization.data(withJSONObject: ["size": size, "chunks": finalHashes, "sha256": digest])
    }
}
