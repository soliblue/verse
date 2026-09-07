import CryptoKit
import Foundation

struct PendingTranscription: Codable, Equatable {
    var selection: SpeechSelection
    var recordingID: String? = nil
    var origin: TranscriptionOrigin? = nil
    var filename: String? = nil
    var localAudioName: String? = nil

    var isRerun: Bool { recordingID != nil }
}

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

    func loadSelectedVersions() -> [String: String] {
        guard let data = try? Data(contentsOf: selectedVersionsURL) else { return [:] }
        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }

    func saveSelectedVersions(_ versions: [String: String]) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(versions).write(to: selectedVersionsURL, options: .atomic)
    }

    func selection(for url: URL) -> SpeechSelection? {
        pendingTranscription(for: url)?.selection
    }

    func pendingTranscription(for url: URL) -> PendingTranscription? {
        guard let data = try? Data(contentsOf: url.appendingPathExtension("json")) else { return nil }
        if let pending = try? JSONDecoder().decode(PendingTranscription.self, from: data) { return pending }
        return (try? JSONDecoder().decode(SpeechSelection.self, from: data)).map { PendingTranscription(selection: $0) }
    }

    func saveSelection(_ selection: SpeechSelection, for url: URL) throws {
        var pending = pendingTranscription(for: url) ?? PendingTranscription(selection: selection)
        pending.selection = selection
        try savePendingTranscription(pending, for: url)
    }

    func savePendingTranscription(_ pending: PendingTranscription, for url: URL) throws {
        try JSONEncoder().encode(pending).write(to: url.appendingPathExtension("json"), options: .atomic)
    }

    func prepareRerun(audio: URL, item: Transcription, selection: SpeechSelection, localAudioName: String) throws -> URL {
        try FileManager.default.createDirectory(at: pendingDirectory, withIntermediateDirectories: true)
        let fileExtension = URL(fileURLWithPath: item.filename).pathExtension
        let destination = pendingDirectory.appendingPathComponent("Rerun-\(UUID().uuidString).\(fileExtension.isEmpty ? audio.pathExtension : fileExtension)")
        let pending = PendingTranscription(selection: selection, recordingID: item.recordingKey,
                                           origin: item.origin, filename: item.filename, localAudioName: localAudioName)
        try savePendingTranscription(pending, for: destination)
        let copied = Result { try FileManager.default.copyItem(at: audio, to: destination) }
        if case .failure = copied { try? removePending(destination) }
        try copied.get()
        return destination
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

    func keepAudio(_ url: URL, id: String, existingName: String? = nil) throws -> String {
        let name = existingName ?? id + "." + url.pathExtension
        guard name == URL(fileURLWithPath: name).lastPathComponent else { throw SpeechFailure("This recording has an invalid audio filename.") }
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

    func deleteAudio(for item: Transcription, retaining items: [Transcription] = []) throws {
        guard !items.contains(where: { $0.localAudioName != nil && $0.localAudioName == item.localAudioName }) else { return }
        if let url = try? audio(for: item) { try FileManager.default.removeItem(at: url) }
    }

    static func localID(for url: URL) -> String {
        "local-" + SHA256.hash(data: Data(url.lastPathComponent.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func merging(server: [Transcription], cached: [Transcription]) -> [Transcription] {
        let received = Set(server.map(\.id))
        let preserved = cached.filter { !received.contains($0.id) }
        let existing = Dictionary(cached.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        let remote = server.map { incoming in
            guard let previous = existing[incoming.id] else { return incoming }
            var result = incoming
            result.filename = previous.filename
            result.recordingID = previous.recordingID
            result.localAudioName = previous.localAudioName
            result.customPrompt = previous.customPrompt
            result.language = previous.language
            result.origin = previous.origin ?? incoming.origin
            result.engine = previous.engine ?? incoming.engine
            result.writingStyle = previous.writingStyle ?? incoming.writingStyle
            if previous.state == "completed", incoming.state == "completed", previous.originalText == incoming.text {
                result.text = previous.text
                result.originalText = previous.originalText
                result.writingFallback = previous.writingFallback
            }
            return result
        }
        return (preserved + remote).sorted { $0.date > $1.date }
    }

    private var indexURL: URL { directory.appendingPathComponent("transcriptions.json") }
    private var selectedVersionsURL: URL { directory.appendingPathComponent("selected-versions.json") }
}
