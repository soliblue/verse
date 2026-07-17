import Foundation
import Observation

@MainActor
@Observable
final class TopicsStore {
    var markdown = ""
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var statusMessage: String?
    private var savedMarkdown = ""

    var hasChanges: Bool { markdown != savedMarkdown }
    var canSave: Bool { hasChanges && !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var isBusy: Bool { isLoading || isSaving }

    func load(repository: TopicsRepository) async {
        guard !isBusy, !hasChanges else { return }
        isLoading = true
        if let document = await repository.load() {
            markdown = document.markdown
            savedMarkdown = document.markdown
            statusMessage = nil
        } else {
            statusMessage = "Preferences could not be opened."
        }
        isLoading = false
    }

    func save(repository: TopicsRepository) async {
        guard canSave, !isBusy else { return }
        isSaving = true
        let document = PreferencesDocument(markdown: markdown)
        let result = await repository.save(document)
        savedMarkdown = markdown
        switch result {
        case .synced:
            statusMessage = "Saved."
        case .pending:
            statusMessage = "Saved on this device. VPS sync will retry automatically."
        case .rejected:
            statusMessage = "Saved on this device, but the VPS rejected the Markdown structure."
        }
        isSaving = false
    }
}
