import Observation

@MainActor
@Observable
final class NightjarRunStore {
    private(set) var running: NightjarJob?
    private(set) var message: String?

    func run(_ job: NightjarJob, api: APIClient) async {
        guard running == nil else { return }
        running = job
        let response = await api.post(
            APIEndpoint.run(job),
            body: [String: String](),
            as: NightjarRunResponse.self
        )
        message = response == nil ? "Could not start (job.rawValue)." : "(job.title) started."
        running = nil
    }
}
