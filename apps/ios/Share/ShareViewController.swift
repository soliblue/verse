import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let status = UILabel()
    private let transcript = UITextView()
    private let copy = UIButton(type: .system)
    private let done = UIButton(type: .system)
    private var pollTask: Task<Void, Never>?
    private var uploadTask: URLSessionUploadTask?
    private var attachmentProgress: Progress?
    private var temporaryFile: URL?
    private var hasFinished = false
    private var waitingForServerApproval = false
    private var selection = SpeechSelection.current

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        status.text = "Preparing audio…"
        status.font = .preferredFont(forTextStyle: .headline)
        status.numberOfLines = 0
        transcript.isEditable = false
        transcript.font = .preferredFont(forTextStyle: .body)
        copy.setTitle("Copy text", for: .normal)
        copy.isEnabled = false
        copy.addTarget(self, action: #selector(copyText), for: .touchUpInside)
        done.setTitle("Cancel", for: .normal)
        done.addTarget(self, action: #selector(finish), for: .touchUpInside)
        let row = UIStackView(arrangedSubviews: [copy, done])
        row.distribution = .equalSpacing
        let stack = UIStackView(arrangedSubviews: [status, transcript, row])
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
        guard !VerseBridge.token.isEmpty else {
            status.text = "Import this file in Verse for on-device transcription, or add your server token in Verse Settings to use sharing."
            done.setTitle("Done", for: .normal)
            return
        }
        if VerseBridge.onDeviceTranscriptionEnabled {
            waitingForServerApproval = true
            status.text = "Shared files use your server. To keep audio on your iPhone, use Import audio inside Verse."
            copy.setTitle("Transcribe on server", for: .normal)
            copy.isEnabled = true
            return
        }
        loadAttachment()
    }

    private func loadAttachment() {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] }
        guard let provider = providers.first,
              let type = provider.registeredTypeIdentifiers.first(where: {
                  guard let type = UTType($0) else { return false }
                  return type.conforms(to: .audio) || type.conforms(to: .movie)
              }) ?? provider.registeredTypeIdentifiers.first else {
            status.text = "Share an audio or video file to transcribe it."
            done.setTitle("Done", for: .normal)
            return
        }
        attachmentProgress = provider.loadFileRepresentation(forTypeIdentifier: type) { [weak self] url, error in
            guard let url, error == nil,
                  let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                  size <= 50 * 1024 * 1024 else {
                DispatchQueue.main.async {
                    self?.status.text = "Could not read this file. Choose audio under 50 MB."
                    self?.done.setTitle("Done", for: .normal)
                }
                return
            }
            let filename = url.lastPathComponent
            let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(url.pathExtension)
            guard (try? FileManager.default.copyItem(at: url, to: temporary)) != nil else {
                DispatchQueue.main.async {
                    self?.status.text = "Could not prepare this file. Try sharing it again."
                    self?.done.setTitle("Done", for: .normal)
                }
                return
            }
            DispatchQueue.main.async {
                guard let self, !self.hasFinished else {
                    try? FileManager.default.removeItem(at: temporary)
                    return
                }
                self.upload(temporary, filename: filename)
            }
        }
    }

    private func upload(_ file: URL, filename: String) {
        temporaryFile = file
        selection.onDevice = false
        selection.model = VerseBridge.model
        guard var components = URLComponents(string: VerseBridge.baseURL + "/v1/transcriptions"),
              components.scheme == "https", components.host != nil else {
            status.text = "The server needs an HTTPS address. Check Verse Settings."
            done.setTitle("Done", for: .normal)
            return
        }
        components.queryItems = [
            URLQueryItem(name: "model", value: selection.model),
            URLQueryItem(name: "language", value: selection.language),
            URLQueryItem(name: "filename", value: filename),
            URLQueryItem(name: "origin", value: "shared")
        ]
        guard let url = components.url else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer " + VerseBridge.token, forHTTPHeaderField: "Authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120
        status.text = "Uploading… Keep this sheet open."
        uploadTask = URLSession.shared.uploadTask(with: request, fromFile: file) { [weak self] data, response, error in
            try? FileManager.default.removeItem(at: file)
            guard error == nil, let response = response as? HTTPURLResponse,
                  (200...299).contains(response.statusCode), let data,
                  let job = try? JSONDecoder().decode(ShareJob.self, from: data) else {
                DispatchQueue.main.async {
                    self?.status.text = "Upload failed. Check your connection and token in Verse."
                    self?.done.setTitle("Done", for: .normal)
                }
                return
            }
            DispatchQueue.main.async {
                guard let self, !self.hasFinished else { return }
                VerseBridge.saveOptions(self.selection, for: job.id)
                if VerseBridge.pendingJobID.isEmpty { VerseBridge.pendingJobID = job.id }
                self.poll(job.id)
            }
        }
        uploadTask?.resume()
    }

    private func poll(_ id: String) {
        done.setTitle("Done", for: .normal)
        status.text = "Transcribing… You can close this and find it in Verse."
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let url = URL(string: VerseBridge.baseURL + "/v1/transcriptions/" + id) else { return }
                var request = URLRequest(url: url)
                request.setValue("Bearer " + VerseBridge.token, forHTTPHeaderField: "Authorization")
                guard let (data, response) = try? await URLSession.shared.data(for: request),
                      (response as? HTTPURLResponse)?.statusCode == 200,
                      let job = try? JSONDecoder().decode(ShareJob.self, from: data) else {
                    self?.status.text = "Connection lost. Your transcription will be in Verse."
                    return
                }
                if job.state == "completed" {
                    let output = await TranscriptDelivery.prepare(id: job.id, text: job.text ?? "", language: job.detectedLanguage)
                    guard !Task.isCancelled, !VerseBridge.isDeleted(job.id) else { return }
                    self?.status.text = output.fallback?.message ?? "Transcribed"
                    self?.transcript.text = output.text
                    self?.copy.isEnabled = !output.text.isEmpty
                    VerseBridge.publishTranscriptionResult(id: job.id, statusCode: 200, state: job.state, text: output.text, error: nil)
                    return
                }
                if job.state == "failed" {
                    self?.status.text = job.error ?? "Transcription failed. Try again in Verse."
                    if VerseBridge.pendingJobID == job.id {
                        VerseBridge.pendingJobID = ""
                        VerseBridge.statusText = ""
                        VerseBridge.errorText = job.error ?? "Transcription failed. Try again in Verse."
                    }
                    return
                }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    @objc private func copyText() {
        if waitingForServerApproval {
            waitingForServerApproval = false
            copy.setTitle("Copy text", for: .normal)
            copy.isEnabled = false
            status.text = "Preparing audio…"
            loadAttachment()
            return
        }
        UIPasteboard.general.string = transcript.text
        copy.setTitle("Copied", for: .normal)
    }

    @objc private func finish() {
        hasFinished = true
        attachmentProgress?.cancel()
        uploadTask?.cancel()
        pollTask?.cancel()
        if let temporaryFile { try? FileManager.default.removeItem(at: temporaryFile) }
        extensionContext?.completeRequest(returningItems: nil)
    }
}
