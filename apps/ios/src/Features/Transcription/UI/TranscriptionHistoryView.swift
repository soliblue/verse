import SwiftUI

struct TranscriptionHistoryView: View {
    @Bindable var store: TranscriptionStore
    let minimumHeight: CGFloat
    let openTranscript: (String) -> Void
    private let green = Color(red: 0, green: 0.39, blue: 0.22)

    var body: some View {
        let days = sections
        LazyVStack(alignment: .leading, spacing: 0) {
            HStack {
                if let day = days.first?.day, store.pendingAudio.isEmpty {
                    Text(day, format: .dateTime.month(.abbreviated).day())
                        .font(.caption.weight(.semibold))
                } else {
                    Text("Recordings").font(.subheadline.weight(.semibold))
                }
                Spacer()
                Button {
                    store.perform { try await store.activateKeyboard() }
                } label: {
                    Image(systemName: "keyboard").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Activate keyboard")
                .disabled(store.recorder.isRecording || store.isUploading || store.isStartingRecording)
            }
            .foregroundStyle(green)
            if store.items.isEmpty && store.pendingAudio.isEmpty {
                Text("Your recordings will appear here.").font(.body).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
            }
            ForEach(store.pendingAudio, id: \.self) { url in
                HStack {
                    Button {
                        store.perform { try await store.upload(url) }
                    } label: { Label("Retry recording", systemImage: "arrow.clockwise") }
                    Spacer()
                    Button(role: .destructive) {
                        store.perform { try store.discardPending(url) }
                    } label: { Image(systemName: "trash").frame(width: 44, height: 44) }
                    .accessibilityLabel("Delete pending recording")
                }
                .disabled(store.isRerunning || store.isUploading || store.recorder.isRecording)
                Divider().overlay(green.opacity(0.25))
            }
            ForEach(days, id: \.day) { section in
                if section.day != days.first?.day || !store.pendingAudio.isEmpty {
                    Text(section.day, format: .dateTime.month(.abbreviated).day())
                        .font(.caption.weight(.semibold)).foregroundStyle(green)
                        .padding(.top, 16).padding(.bottom, 4)
                }
                ForEach(section.items, id: \.recordingKey) { item in
                    Button { openTranscript(item.recordingKey) } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.title).font(.body).lineLimit(3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            HStack(alignment: .firstTextBaseline) {
                                if item.isPending {
                                    ProgressView().controlSize(.mini)
                                }
                                Text(item.state == "failed" ? "Failed · \(item.modelLabel)" : item.modelLabel)
                                    .foregroundStyle(item.state == "failed" ? .red : green)
                                if let duration = item.durationSeconds {
                                    Text(durationLabel(duration)).foregroundStyle(green)
                                }
                                Spacer(minLength: 4)
                                Text(item.date, format: .dateTime.hour().minute())
                                    .foregroundStyle(.secondary)
                            }
                            .font(.caption)
                            let count = store.versions(for: item.id).count
                            if count > 1 {
                                Text("\(count) versions").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 14).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("recording-\(item.recordingKey)")
                    .contextMenu {
                        Button("Delete", role: .destructive) { store.perform { try await store.delete(item) } }
                    }
                    Divider().overlay(green.opacity(0.15))
                }
            }
            Color.clear.frame(height: 12).accessibilityHidden(true)
        }
        .frame(minHeight: minimumHeight, alignment: .top)
        .padding(.horizontal, 14).padding(.top, 6).padding(.bottom, 16)
        .background {
            Image("CitrusReceipt").resizable(capInsets: EdgeInsets(top: 20, leading: 20, bottom: 32, trailing: 20))
                .accessibilityHidden(true)
        }
    }

    private var sections: [(day: Date, items: [Transcription])] {
        Dictionary(grouping: store.recordings) { Calendar.current.startOfDay(for: $0.date) }
            .map { (day: $0.key, items: $0.value) }
            .sorted { $0.day > $1.day }
    }

    private func durationLabel(_ seconds: Double) -> String {
        let seconds = max(0, Int(seconds))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
