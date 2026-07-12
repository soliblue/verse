import SwiftUI

struct TopicEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: TopicEditorDraft
    let onSave: (TopicEditorDraft) -> Void

    init(draft: TopicEditorDraft, onSave: @escaping (TopicEditorDraft) -> Void) {
        _draft = State(initialValue: draft)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Topic") {
                    TextField("Name", text: $draft.name)
                    Picker("Kind", selection: $draft.kind) {
                        ForEach(TopicKind.allCases) { kind in
                            Label(kind.label, systemImage: kind.systemImage)
                                .tag(kind)
                        }
                    }
                    Toggle("Enabled", isOn: $draft.isEnabled)
                }
                Section("Guidance") {
                    TextField(
                        "What should Nightjar look for?",
                        text: $draft.description,
                        axis: .vertical
                    )
                    .lineLimit(3...7)
                }
            }
            .navigationTitle(draft.name.isEmpty ? "New topic" : "Edit topic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(
                        draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || draft.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
        }
    }
}
