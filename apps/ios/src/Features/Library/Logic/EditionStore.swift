import Observation

@MainActor
@Observable
final class EditionStore {
    private(set) var edition: EditionPayload?
    private(set) var isLoading = false
    private(set) var loadFailed = false

    func load(id: String, repository: EditionRepository, configuration: ServerConfiguration) async {
        isLoading = edition == nil
        edition = repository.localEdition(id: id)
        if configuration.isConfigured,
            let fresh = await repository.refreshEdition(id: id)
        {
            edition = fresh
        }
        loadFailed = edition == nil
        isLoading = false
    }
}
