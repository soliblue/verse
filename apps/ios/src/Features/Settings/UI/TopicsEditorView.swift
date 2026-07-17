import SwiftUI

struct TopicsEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let repository: TopicsRepository

    var body: some View {
        NavigationStack {
            TopicsView(repository: repository)
                .navigationTitle("Topics")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}
