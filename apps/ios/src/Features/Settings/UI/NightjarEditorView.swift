import SwiftUI

struct NightjarEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let job: NightjarJob
    let api: APIClient
    @State private var store = NightjarEditorStore()

    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading && store.markdown.isEmpty {
                    ProgressView()
                } else {
                    TextEditor(text: $store.markdown)
                        .font(.body.monospaced())
                        .padding(.horizontal, 12)
                        .scrollDismissesKeyboard(.interactively)
                }
            }
            .background(VerseTheme.paper)
            .navigationTitle(job.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await store.save(job, api: api) { dismiss() }
                        }
                    }
                    .disabled(!store.canSave || store.isSaving)
                }
            }
            .overlay(alignment: .bottom) {
                if let message = store.message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(VerseTheme.secondaryInk)
                        .padding()
                }
            }
        }
        .task { await store.load(job, api: api) }
    }
}
