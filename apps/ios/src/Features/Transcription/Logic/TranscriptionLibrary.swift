import CryptoKit
import Foundation

struct TranscriptionLibrary {
    let directory: URL
    let pendingDirectory: URL

    init(directory: URL? = nil, pendingDirectory: URL? = nil) {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.directory = directory ?? support.appendingPathComponent("Transcriptions", isDirectory: true)
        self.pendingDirectory = pendingDirectory ?? support.appendingPathComponent("PendingAudio", isDirectory: true)
    }

    func load() -> [Transcription] {
        let legacy = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("transcriptions.json")
        let data = (try? Data(contentsOf: indexURL)) ?? (try? Data(contentsOf: legacy))
        guard let data else { return [] }
        return (try? JSONDecoder().decode([Transcription].self, from: data)) ?? []
    }

    func save(_ items: [Transcription]) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(items).write(to: indexURL, options: .atomic)
    }

    func selection(for url: URL) -> SpeechSelection? {
        guard let data = try? Data(contentsOf: url.appendingPathExtension("json")) else { return nil }
        return try? JSONDecoder().decode(SpeechSelection.self, from: data)
    }

    func saveSelection(_ selection: SpeechSelection, for url: URL) throws {
        try JSONEncoder().encode(selection).write(to: url.appendingPathExtension("json"), options: .atomic)
    }

    func pendingAudio() -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(at: pendingDirectory, includingPropertiesForKeys: [.isRegularFileKey])) ?? [])
            .filter { $0.pathExtension != "json" && (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    func removePending(_ url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        let metadata = url.appendingPathExtension("json")
        if FileManager.default.fileExists(atPath: metadata.path) { try FileManager.default.removeItem(at: metadata) }
    }

    func keepAudio(_ url: URL, id: String) throws -> String {
        let name = id + "." + url.pathExtension
        let destination = directory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.copyItem(at: url, to: destination)
        }
        return name
    }

    func audio(for item: Transcription) throws -> URL {
        guard let name = item.localAudioName, name == URL(fileURLWithPath: name).lastPathComponent else {
            throw SpeechFailure("This recording is not stored on this iPhone.")
        }
        let url = directory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else { throw SpeechFailure("This recording is no longer on this iPhone.") }
        return url
    }

    func deleteAudio(for item: Transcription) throws {
        if let url = try? audio(for: item) { try FileManager.default.removeItem(at: url) }
    }

    static func localID(for url: URL) -> String {
        "local-" + SHA256.hash(data: Data(url.lastPathComponent.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func merging(server: [Transcription], cached: [Transcription]) -> [Transcription] {
        let local = cached.filter(\.isLocal)
        let existing = Dictionary(cached.filter { !$0.isLocal }.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        let remote = server.map { incoming in
            guard let previous = existing[incoming.id], previous.state == "completed", incoming.state == "completed",
                  previous.originalText == incoming.text else { return incoming }
            var result = incoming
            result.text = previous.text
            result.originalText = previous.originalText
            result.writingStyle = previous.writingStyle
            result.writingFallback = previous.writingFallback
            return result
        }
        return (local + remote).sorted { $0.date > $1.date }
    }

    private var indexURL: URL { directory.appendingPathComponent("transcriptions.json") }
}
