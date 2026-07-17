import Foundation
import Observation

@MainActor
@Observable
final class NightjarEditorStore {
    var markdown = ""
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var message: String?
    private var savedMarkdown = ""

    var canSave: Bool {
        markdown != savedMarkdown && !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func load(_ job: NightjarJob, api: APIClient) async {
        guard !isLoading else { return }
        isLoading = true
        if let document = await api.get(APIEndpoint.guidance(job), as: NightjarGuidance.self) {
            markdown = document.markdown
            savedMarkdown = document.markdown
            message = nil
        } else {
            message = "Could not load guidance."
        }
        isLoading = false
    }

    func save(_ job: NightjarJob, api: APIClient) async -> Bool {
        guard canSave, !isSaving else { return false }
        isSaving = true
        let request = NightjarGuidance(kind: job.rawValue, markdown: markdown)
        let response = await api.put(APIEndpoint.guidance(job), body: request, as: NightjarGuidance.self)
        if let response {
            markdown = response.markdown
            savedMarkdown = response.markdown
            message = "Saved."
        } else {
            message = "Could not save guidance."
        }
        isSaving = false
        return response != nil
    }
}
