import Observation

@MainActor
@Observable
final class ExploreStore {
    private(set) var payload: ExplorePayload?
    private(set) var isLoading = false
    private(set) var statusMessage: String?

    func load(repository: ExploreRepository, configuration: ServerConfiguration) async {
        isLoading = payload == nil
        payload = repository.local()
        isLoading = false
        if configuration.isConfigured { await refresh(repository: repository) }
        if payload == nil { statusMessage = "This screen is not available offline yet." }
    }

    func refresh(repository: ExploreRepository) async {
        if let fresh = await repository.refresh() {
            payload = fresh
            statusMessage = nil
        } else if payload != nil {
            statusMessage = "Showing downloaded data."
        }
    }
}
