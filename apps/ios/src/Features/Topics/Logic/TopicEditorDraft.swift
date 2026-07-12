import Foundation

struct TopicEditorDraft: Identifiable {
    let id: String
    var name: String
    var kind: TopicKind
    var description: String
    var isEnabled: Bool

    init(topic: Topic? = nil) {
        id = topic?.id ?? "topic-\(UUID().uuidString.lowercased())"
        name = topic?.name ?? ""
        kind = topic?.kind ?? .interest
        description = topic?.description ?? ""
        isEnabled = topic?.isEnabled ?? true
    }
}
