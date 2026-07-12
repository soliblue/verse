import Observation
import SwiftUI

@MainActor
@Observable
final class TopicsStore {
    private(set) var topics: [Topic] = []
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var statusMessage: String?
    var isBusy: Bool { isLoading || isSaving }

    func load(repository: TopicsRepository) async {
        guard !isBusy else { return }
        isLoading = true
        if let list = await repository.load() {
            topics = list.topics.sorted { $0.position < $1.position }
            statusMessage = nil
        } else {
            statusMessage = "Topics could not be opened."
        }
        isLoading = false
    }

    func toggle(_ id: String, repository: TopicsRepository) async {
        guard !isBusy else { return }
        if let index = topics.firstIndex(where: { $0.id == id }) {
            topics[index].isEnabled.toggle()
            await save(repository: repository)
        }
    }

    func upsert(_ draft: TopicEditorDraft, repository: TopicsRepository) async {
        guard !isBusy else { return }
        if let index = topics.firstIndex(where: { $0.id == draft.id }) {
            topics[index].name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            topics[index].kind = draft.kind
            topics[index].description = draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
            topics[index].isEnabled = draft.isEnabled
        } else {
            topics.append(
                Topic(
                    id: draft.id,
                    name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    kind: draft.kind,
                    description: draft.description.trimmingCharacters(in: .whitespacesAndNewlines),
                    isEnabled: draft.isEnabled,
                    position: topics.count + 1
                )
            )
        }
        normalizePositions()
        await save(repository: repository)
    }

    func delete(at offsets: IndexSet, repository: TopicsRepository) async {
        guard !isBusy else { return }
        topics.remove(atOffsets: offsets)
        normalizePositions()
        await save(repository: repository)
    }

    func move(from offsets: IndexSet, to destination: Int, repository: TopicsRepository) async {
        guard !isBusy else { return }
        topics.move(fromOffsets: offsets, toOffset: destination)
        normalizePositions()
        await save(repository: repository)
    }

    private func normalizePositions() {
        for index in topics.indices {
            topics[index].position = index + 1
        }
    }

    private func save(repository: TopicsRepository) async {
        isSaving = true
        statusMessage = await repository.save(TopicList(topics: topics))
            ? nil
            : "Saved on this device. VPS sync will retry automatically."
        isSaving = false
    }
}
