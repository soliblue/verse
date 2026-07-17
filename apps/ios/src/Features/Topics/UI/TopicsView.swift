import SwiftUI

struct TopicsView: View {
    let repository: TopicsRepository
    @State private var store = TopicsStore()
    @FocusState private var editorFocused: Bool

    var body: some View {
        @Bindable var store = store

        Group {
            if store.isLoading && store.markdown.isEmpty {
                ProgressView("Loading preferences")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    if let message = store.statusMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(VerseTheme.secondaryInk)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                    }

                    TextEditor(text: $store.markdown)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(VerseTheme.ink)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 14)
                        .focused($editorFocused)
                        .simultaneousGesture(TapGesture().onEnded { editorFocused = true })
                        .scrollDismissesKeyboard(.immediately)
                        .autocorrectionDisabled()
                        .accessibilityLabel("Preferences Markdown")
                        .accessibilityIdentifier("topics-markdown-editor")

                    Text("This exact Markdown guides the next Nightjar edition.")
                        .font(.footnote)
                        .foregroundStyle(VerseTheme.secondaryInk)
                        .accessibilityIdentifier("topics-editor-state")
                        .accessibilityValue(editorFocused ? "focused" : "unfocused")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                }
            }
        }
        .background(VerseTheme.paper)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    editorFocused = false
                    Task { await store.save(repository: repository) }
                }
                .disabled(!store.canSave || store.isBusy)
                .accessibilityIdentifier("topics-save")
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { editorFocused = false }
            }
        }
        .task { await store.load(repository: repository) }
    }
}
