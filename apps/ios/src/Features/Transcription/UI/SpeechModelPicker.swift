import SwiftUI

struct SpeechModelPicker: View {
    let engine: LocalSpeechEngine
    let selection: SpeechSelection
    var requiresReadyModel = false
    let onSelect: (SpeechSelection) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selected: SpeechModelChoice?
    @State private var pending: SpeechSelection?
    @State private var removing: SpeechModelChoice?
    private let green = Color(red: 0, green: 0.39, blue: 0.22)
    private let ink = Color(red: 0.12, green: 0.16, blue: 0.10)

    var body: some View {
        NavigationStack {
            List {
                ForEach(SpeechModelChoice.all) { choice in
                    modelRow(choice)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing) {
                            if choice.onDevice, engine.installedModelIDs.contains(choice.model) {
                                Button(role: .destructive) { removing = choice } label: {
                                    Label("Remove download", systemImage: "trash")
                                }
                                .disabled(engine.isBusy || engine.downloadingModelID != nil)
                            }
                        }
                }
                if let error = engine.error {
                    Text(error).font(.footnote).foregroundStyle(.red).listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background { Image("CitrusPaper").resizable().scaledToFill().ignoresSafeArea() }
            .foregroundStyle(ink)
            .tint(green)
            .navigationTitle("Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Image(systemName: "checkmark") }
                        .accessibilityLabel("Done")
                }
            }
            .onChange(of: engine.installedModelIDs) { _, ids in
                guard let pending, ids.contains(pending.model) else { return }
                self.pending = nil
                if requiresReadyModel { onSelect(pending) }
                dismiss()
            }
            .onChange(of: engine.downloadingModelID) { _, value in
                if value == nil, let pending, !engine.installedModelIDs.contains(pending.model) {
                    self.pending = nil
                }
            }
            .onDisappear { pending = nil }
            .confirmationDialog("Remove this model? Your recordings stay saved.", isPresented: Binding(
                get: { removing != nil }, set: { if !$0 { removing = nil } }
            ), titleVisibility: .visible) {
                Button("Remove download", role: .destructive) {
                    guard let choice = removing else { return }
                    removing = nil
                    Task {
                        let result = await Task { try await engine.delete(choice.model) }.result
                        if case .failure(let failure) = result { engine.error = failure.localizedDescription }
                    }
                }
            }
        }
        .presentationBackground { Image("CitrusPaper").resizable().scaledToFill() }
    }

    private func modelRow(_ choice: SpeechModelChoice) -> some View {
        let downloading = choice.onDevice && engine.downloadingModelID == choice.model
        let installed = choice.onDevice && engine.installedModelIDs.contains(choice.model)
        let active = (selected ?? selection.modelChoice) == choice
        return HStack(spacing: 12) {
            Button { select(choice) } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(choice.title)
                        if downloading {
                            ProgressView(value: engine.downloadProgress)
                                .accessibilityLabel("Download progress")
                                .accessibilityValue("\(Int(engine.downloadProgress * 100)) percent")
                                .accessibilityIdentifier("model-progress-" + choice.id)
                        }
                    }
                    Spacer(minLength: 4)
                    if downloading {
                        Text(engine.downloadProgress, format: .percent.precision(.fractionLength(0)))
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    } else if installed || !choice.onDevice {
                        if active { Image(systemName: "checkmark").foregroundStyle(green) }
                        else if installed { Image(systemName: "checkmark.circle").foregroundStyle(.secondary) }
                    } else {
                        if active { Image(systemName: "checkmark").foregroundStyle(green) }
                        Text("~" + (LocalSpeechEngine.modelChoices.first { $0.id == choice.model }?.approximateDownload ?? ""))
                            .font(.caption).foregroundStyle(.secondary)
                        Image(systemName: "arrow.down.circle").foregroundStyle(green)
                    }
                }
                .frame(minHeight: 42)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(engine.isBusy || (!installed && choice.onDevice && engine.downloadingModelID != nil && !downloading))
            .accessibilityIdentifier("model-choice-" + choice.id)
            .accessibilityValue(downloading ? "Downloading" : installed ? "Downloaded" : choice.onDevice ? "Not downloaded" : "Cloud")
            .accessibilityHint(choice.onDevice && !installed ? "Select to download this model." : "")
            if downloading {
                Button {
                    pending = nil
                    engine.cancelDownload()
                } label: { Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44) }
                .buttonStyle(.borderless)
                .accessibilityLabel("Cancel model download")
            }
        }
    }

    private func select(_ choice: SpeechModelChoice) {
        selected = choice
        let updated = selection.replacingModel(choice)
        if choice.onDevice, !engine.installedModelIDs.contains(choice.model) {
            pending = updated
            if !requiresReadyModel { onSelect(updated) }
            engine.download(choice.model)
        } else {
            pending = nil
            onSelect(updated)
            dismiss()
        }
    }
}
