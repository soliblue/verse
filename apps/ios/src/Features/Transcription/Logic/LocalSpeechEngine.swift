import AVFoundation
import CoreML
import NaturalLanguage
import Observation
import WhisperKit

struct LocalSpeechModel: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let variant: String
    let tokenizer: String
    let approximateDownload: String
}

struct LocalSpeechResult: Sendable {
    let text: String
    let language: String
    let duration: Double

    nonisolated init(text: String, language: String, duration: Double) {
        self.text = text
        self.language = language
        self.duration = duration
    }
}

@MainActor
@Observable
final class LocalSpeechEngine {
    static let modelChoices: [LocalSpeechModel] = [
        .init(id: "tiny", name: "Tiny", variant: "openai_whisper-tiny", tokenizer: "openai/whisper-tiny", approximateDownload: "80 MB"),
        .init(id: "base", name: "Base", variant: "openai_whisper-base", tokenizer: "openai/whisper-base", approximateDownload: "150 MB"),
        .init(id: "small", name: "Small", variant: "openai_whisper-small_216MB", tokenizer: "openai/whisper-small", approximateDownload: "220 MB"),
        .init(id: "medium", name: "Medium", variant: "openai_whisper-medium", tokenizer: "openai/whisper-medium", approximateDownload: "1.6 GB"),
        .init(id: "large-v3", name: "Large v3", variant: "openai_whisper-large-v3_947MB", tokenizer: "openai/whisper-large-v3", approximateDownload: "960 MB"),
        .init(id: "turbo", name: "Large v3 Turbo", variant: "openai_whisper-large-v3-v20240930_626MB", tokenizer: "openai/whisper-large-v3", approximateDownload: "640 MB")
    ]
    private(set) var installedModelIDs: Set<String> = []
    private(set) var downloadingModelID: String?
    private(set) var downloadProgress = 0.0
    private(set) var isPreparing = false
    private(set) var isTranscribing = false
    var error: String?
    @ObservationIgnored private let directory: URL
    @ObservationIgnored private let worker = LocalSpeechWorker()
    @ObservationIgnored private var downloadTask: Task<Void, Never>?
    @ObservationIgnored private var preparation: (id: String, token: UUID, task: Task<Void, Error>)?
    @ObservationIgnored private var loadedModelID: String?
    #if DEBUG
    @ObservationIgnored private var fixtureInstalledModels: Set<String> = []
    #endif

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SpeechModels", isDirectory: true)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing"),
           let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--installed-models=") }) {
            fixtureInstalledModels = Set(argument.dropFirst("--installed-models=".count).split(separator: ",").map(String.init))
        }
        #endif
        refreshInstalled()
    }

    nonisolated deinit {}

    var isBusy: Bool { isPreparing || isTranscribing }

    func refreshInstalled() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            installedModelIDs = fixtureInstalledModels
            VerseBridge.localInstalledModels = installedModelIDs.sorted().joined(separator: ",")
            return
        }
        #endif
        installedModelIDs = Set(Self.modelChoices.filter { model in
            let folder = modelDirectory(model)
            let tokenizer = tokenizerDirectory(model)
            return FileManager.default.fileExists(atPath: folder.appendingPathComponent(".verse-complete").path)
                && ["AudioEncoder.mlmodelc", "TextDecoder.mlmodelc", "MelSpectrogram.mlmodelc"].allSatisfy {
                    FileManager.default.fileExists(atPath: folder.appendingPathComponent($0).path)
                }
                && ["tokenizer.json", "tokenizer_config.json"].allSatisfy {
                    FileManager.default.fileExists(atPath: tokenizer.appendingPathComponent($0).path)
                }
        }.map(\.id))
        VerseBridge.localInstalledModels = installedModelIDs.sorted().joined(separator: ",")
    }

    func download(_ modelID: String) {
        guard downloadingModelID == nil, !isBusy,
              let model = Self.modelChoices.first(where: { $0.id == modelID }),
              !installedModelIDs.contains(modelID) else { return }
        error = nil
        downloadingModelID = modelID
        downloadProgress = 0
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            downloadTask = Task { [weak self] in
                guard let self else { return }
                for step in 1...10 {
                    try? await Task.sleep(for: .milliseconds(200))
                    guard !Task.isCancelled else { break }
                    downloadProgress = Double(step) / 10
                    if step == 4, ProcessInfo.processInfo.arguments.contains("--hold-model-download") {
                        while !Task.isCancelled { try? await Task.sleep(for: .milliseconds(200)) }
                    }
                }
                if !Task.isCancelled { fixtureInstalledModels.insert(modelID); refreshInstalled() }
                downloadingModelID = nil
                downloadProgress = 0
                downloadTask = nil
            }
            return
        }
        #endif
        downloadTask = Task { [weak self] in
            guard let self else { return }
            let operation = Task {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                var resourceValues = URLResourceValues()
                resourceValues.isExcludedFromBackup = true
                var root = directory
                try root.setResourceValues(resourceValues)
                let folder = try await WhisperKit.download(variant: model.variant, downloadBase: directory) { [weak self] progress in
                    let fraction = progress.fractionCompleted * 0.95
                    Task { @MainActor in
                        if self?.downloadingModelID == modelID { self?.downloadProgress = fraction }
                    }
                }
                try Task.checkCancellation()
                let hub = HubApiWrapper(downloadBase: directory)
                let tokenizer = try await hub.snapshot(
                    from: .init(id: model.tokenizer),
                    matching: ["tokenizer.json", "tokenizer_config.json", "config.json", "special_tokens_map.json", "added_tokens.json"]
                )
                _ = try await OfflineSpeechTokenizer(folder: tokenizer)
                try Task.checkCancellation()
                try Data(model.variant.utf8).write(to: folder.appendingPathComponent(".verse-complete"), options: .atomic)
            }
            let result = await withTaskCancellationHandler {
                await operation.result
            } onCancel: {
                operation.cancel()
            }
            if case .failure(let failure) = result, !Task.isCancelled {
                error = failure.localizedDescription
            }
            refreshInstalled()
            downloadingModelID = nil
            downloadProgress = 0
            downloadTask = nil
        }
    }

    func cancelDownload() {
        downloadTask?.cancel()
    }

    func delete(_ modelID: String) async throws {
        guard !isBusy, downloadingModelID == nil else { throw SpeechFailure("Wait for the current model operation to finish.") }
        guard let model = Self.modelChoices.first(where: { $0.id == modelID }) else { return }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            fixtureInstalledModels.remove(modelID)
            installedModelIDs = fixtureInstalledModels
            VerseBridge.localInstalledModels = installedModelIDs.sorted().joined(separator: ",")
            return
        }
        #endif
        defer { refreshInstalled() }
        await worker.unload()
        loadedModelID = nil
        let folder = modelDirectory(model)
        if FileManager.default.fileExists(atPath: folder.path) { try FileManager.default.removeItem(at: folder) }
        let metadata = folder.deletingLastPathComponent().appendingPathComponent(".cache/huggingface/download/\(model.variant)")
        if FileManager.default.fileExists(atPath: metadata.path) { try FileManager.default.removeItem(at: metadata) }
        if !Self.modelChoices.contains(where: { $0.id != modelID && $0.tokenizer == model.tokenizer && installedModelIDs.contains($0.id) }) {
            let tokenizer = tokenizerDirectory(model)
            if FileManager.default.fileExists(atPath: tokenizer.path) { try FileManager.default.removeItem(at: tokenizer) }
        }
    }

    func warm(_ modelID: String) {
        guard installedModelIDs.contains(modelID), !isBusy, loadedModelID != modelID else { return }
        Task { [weak self] in
            guard let self else { return }
            let result = await Task { try await prepare(model: modelID) }.result
            if case .failure(let failure) = result { error = failure.localizedDescription }
        }
    }

    func prepare(model modelID: String) async throws {
        guard let model = Self.modelChoices.first(where: { $0.id == modelID }),
              installedModelIDs.contains(modelID) else {
            throw SpeechFailure("Download this on-device model in Settings first, or switch to Server.")
        }
        if loadedModelID == modelID { return }
        if let preparation {
            try await preparation.task.value
            if preparation.id == modelID { return }
        }
        isPreparing = true
        loadedModelID = nil
        let folder = modelDirectory(model)
        let tokenizer = tokenizerDirectory(model)
        let token = UUID()
        let task = Task { try await worker.prepare(folder: folder, tokenizer: tokenizer) }
        preparation = (modelID, token, task)
        defer {
            if preparation?.token == token { preparation = nil; isPreparing = false }
        }
        try await task.value
        if preparation?.token == token { loadedModelID = modelID }
    }

    func transcribe(url: URL, model: String, language: String) async throws -> LocalSpeechResult {
        guard !isTranscribing else { throw SpeechFailure("Wait for your last transcription to finish.") }
        isTranscribing = true
        defer { isTranscribing = false }
        try await prepare(model: model)
        return try await worker.transcribe(url: url, language: language)
    }

    private func modelDirectory(_ model: LocalSpeechModel) -> URL {
        directory.appending(component: "models").appending(component: "argmaxinc/whisperkit-coreml")
            .appendingPathComponent(model.variant, isDirectory: true)
    }

    private func tokenizerDirectory(_ model: LocalSpeechModel) -> URL {
        directory.appending(component: "models").appending(component: model.tokenizer)
    }
}

private actor LocalSpeechWorker {
    private var engine: WhisperKit?

    func prepare(folder: URL, tokenizer: URL) async throws {
        await unload()
        let localTokenizer = try await OfflineSpeechTokenizer(folder: tokenizer)
        let pipeline = try await WhisperKit(WhisperKitConfig(
            modelFolder: folder.path,
            tokenizerFolder: tokenizer,
            computeOptions: ModelComputeOptions(melCompute: .cpuOnly, audioEncoderCompute: .cpuAndNeuralEngine, textDecoderCompute: .cpuAndNeuralEngine),
            verbose: false,
            prewarm: false,
            load: false,
            download: false
        ))
        pipeline.tokenizer = localTokenizer
        pipeline.textDecoder.isModelMultilingual = true
        try await pipeline.prewarmModels()
        try Task.checkCancellation()
        try await pipeline.loadModels()
        engine = pipeline
    }

    func transcribe(url: URL, language: String) async throws -> LocalSpeechResult {
        guard let engine else { throw SpeechFailure("The on-device model is not ready. Try again.") }
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite, duration > 0 else { throw SpeechFailure("This recording has no readable audio.") }
        let automaticLanguage = language.isEmpty || language == "auto"
        let results = try await engine.transcribe(
            audioPath: url.path,
            audioInputOptions: AudioInputOptions(audioLoadingMode: .incremental),
            decodeOptions: DecodingOptions(
                language: automaticLanguage ? nil : language,
                detectLanguage: automaticLanguage,
                skipSpecialTokens: true,
                wordTimestamps: false,
                concurrentWorkerCount: 1,
                chunkingStrategy: .vad
            )
        )
        try Task.checkCancellation()
        return LocalSpeechResult(
            text: results.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines),
            language: results.first?.language ?? (automaticLanguage ? "" : language),
            duration: duration
        )
    }

    func unload() async {
        await engine?.unloadModels()
        engine = nil
    }
}

final class OfflineSpeechTokenizer: WhisperTokenizer, @unchecked Sendable {
    nonisolated let tokenizer: TokenizerWrapper
    nonisolated let specialTokens: SpecialTokens
    nonisolated let allLanguageTokens: Set<Int>

    nonisolated init(folder: URL) async throws {
        let tokenizer = try await AutoTokenizerWrapper.from(modelFolder: folder)
        func token(_ value: String, _ alternative: String? = nil) throws -> Int {
            guard let id = tokenizer.convertTokenToId(value) ?? alternative.flatMap({ tokenizer.convertTokenToId($0) }) else {
                throw SpeechFailure("The downloaded tokenizer is incomplete. Download the model again.")
            }
            return id
        }
        self.tokenizer = tokenizer
        specialTokens = try SpecialTokens(
            endToken: token("<|endoftext|>"), englishToken: token("<|en|>"),
            noSpeechToken: token("<|nospeech|>", "<|nocaptions|>"), noTimestampsToken: token("<|notimestamps|>"),
            specialTokenBegin: token("<|endoftext|>"), startOfPreviousToken: token("<|startofprev|>"),
            startOfTranscriptToken: token("<|startoftranscript|>"), timeTokenBegin: token("<|0.00|>"),
            transcribeToken: token("<|transcribe|>"), translateToken: token("<|translate|>"),
            whitespaceToken: tokenizer.convertTokenToId(" ") ?? 220
        )
        allLanguageTokens = Set(Constants.languages.values.compactMap { tokenizer.convertTokenToId("<|\($0)|>") })
    }

    nonisolated func encode(text: String) -> [Int] { tokenizer.encode(text: text) }
    nonisolated func decode(tokens: [Int]) -> String { tokenizer.decode(tokens: tokens) }
    nonisolated func convertTokenToId(_ token: String) -> Int? { tokenizer.convertTokenToId(token) }
    nonisolated func convertIdToToken(_ id: Int) -> String? { tokenizer.convertIdToToken(id) }

    nonisolated func splitToWordTokens(tokenIds: [Int]) -> (words: [String], wordTokens: [[Int]]) {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(decode(tokens: tokenIds.filter { $0 < specialTokens.specialTokenBegin }))
        let language = recognizer.dominantLanguage.flatMap { Locale(identifier: $0.rawValue).language.languageCode?.identifier }
        let separatesCharacters = ["zh", "ja", "th", "lo", "my", "yue"].contains(language ?? "")
        var words: [String] = []
        var wordTokens: [[Int]] = []
        var pending: [Int] = []
        for id in tokenIds {
            pending.append(id)
            let value = decode(tokens: pending)
            if value.hasSuffix("\u{fffd}") { continue }
            let punctuation = value.trimmingCharacters(in: .whitespaces).unicodeScalars.allSatisfy { CharacterSet.punctuationCharacters.contains($0) }
            if words.isEmpty || separatesCharacters || id >= specialTokens.specialTokenBegin || value.hasPrefix(" ") || punctuation {
                words.append(value)
                wordTokens.append(pending)
            } else {
                words[words.count - 1] += value
                wordTokens[wordTokens.count - 1].append(contentsOf: pending)
            }
            pending.removeAll(keepingCapacity: true)
        }
        if !pending.isEmpty { words.append(decode(tokens: pending)); wordTokens.append(pending) }
        return (words, wordTokens)
    }
}
