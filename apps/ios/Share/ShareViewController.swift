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
            status.text = "Open Verse and enter your server token first."
            done.setTitle("Done", for: .normal)
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
        guard var components = URLComponents(string: VerseBridge.baseURL + "/v1/transcriptions") else { return }
        components.queryItems = [
            URLQueryItem(name: "model", value: VerseBridge.model),
            URLQueryItem(name: "language", value: VerseBridge.language),
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
            VerseBridge.pendingJobID = job.id
            DispatchQueue.main.async {
                guard let self, !self.hasFinished else { return }
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
                    self?.status.text = "Transcribed"
                    self?.transcript.text = job.text ?? ""
                    self?.copy.isEnabled = !(job.text ?? "").isEmpty
                    VerseBridge.transcriptText = job.text ?? ""
                    VerseBridge.transcriptID = job.id
                    if VerseBridge.pendingJobID == job.id {
                        VerseBridge.pendingJobID = ""
                        VerseBridge.statusText = ""
                        VerseBridge.errorText = ""
                    }
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
