import SwiftUI

struct TranscriptionHistoryView: View {
    @Bindable var store: TranscriptionStore
    let openTranscript: (String) -> Void
    private let green = Color(red: 0, green: 0.39, blue: 0.22)

    var body: some View {
        Section {
            if store.items.isEmpty && store.pendingAudio.isEmpty {
                Text("Your recordings will appear here.")
                    .font(.body).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
                    .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(receiptBackground)
            }
            ForEach(store.pendingAudio, id: \.self) { url in
                Button {
                    store.perform { try await store.upload(url) }
                } label: {
                    Label("Retry recording", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        store.perform { try store.discardPending(url) }
                    } label: { Label("Delete", systemImage: "trash") }
                }
                .disabled(store.isRerunning || store.isUploading || store.recorder.isRecording)
                .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                .listRowBackground(receiptBackground)
            }
            ForEach(sections, id: \.day) { section in
                Text(dayLabel(section.day))
                    .font(.caption.weight(.semibold)).foregroundStyle(green)
                    .listRowInsets(EdgeInsets(top: 14, leading: 20, bottom: 4, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(receiptBackground)
                ForEach(section.items, id: \.recordingKey) { anchor in
                    recordingRow(anchor)
                        .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20))
                        .listRowSeparatorTint(green.opacity(0.15))
                        .listRowBackground(receiptBackground)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                store.perform { try await store.delete(anchor) }
                            } label: { Label("Delete", systemImage: "trash") }
                            .disabled(store.rerunningRecordingID == anchor.recordingKey)
                        }
                }
            }
            Image("CitrusReceipt")
                .resizable(capInsets: EdgeInsets(top: 20, leading: 20, bottom: 32, trailing: 20))
                .frame(height: 64).offset(y: -32)
                .frame(height: 32, alignment: .top).clipped()
                .padding(.horizontal, 8)
                .accessibilityHidden(true)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
    }

    private func recordingRow(_ anchor: Transcription) -> some View {
        let item = store.preferredVersion(for: anchor.recordingKey) ?? anchor
        let count = store.versions(for: anchor.recordingKey).count
        return Button { openTranscript(anchor.recordingKey) } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.title).font(.body).lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                }
                HStack(spacing: 5) {
                    if item.isPending { ProgressView().controlSize(.mini) }
                    if item.state == "failed" {
                        Image(systemName: "exclamationmark.circle").foregroundStyle(.red)
                    }
                    Text(metadata(item, date: anchor.date, count: count))
                        .lineLimit(1).minimumScaleFactor(0.85)
                        .accessibilityIdentifier("recording-metadata-" + anchor.recordingKey)
                }
                .font(.caption).monospacedDigit().foregroundStyle(green)
            }
            .frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("recording-" + anchor.recordingKey)
        .accessibilityLabel(item.title + ", " + metadata(item, date: anchor.date, count: count) + ", \(count) versions")
        .contextMenu {
            Button("Delete", systemImage: "trash", role: .destructive) {
                store.perform { try await store.delete(anchor) }
            }
            .disabled(store.rerunningRecordingID == anchor.recordingKey)
        }
    }

    private var receiptBackground: some View {
        Image("CitrusReceipt")
            .resizable(capInsets: EdgeInsets(top: 20, leading: 20, bottom: 32, trailing: 20))
            .padding(.vertical, -36).clipped().padding(.horizontal, 8)
    }

    private var sections: [(day: Date, items: [Transcription])] {
        Dictionary(grouping: store.recordings) { Calendar.current.startOfDay(for: $0.date) }
            .map { (day: $0.key, items: $0.value) }
            .sorted { $0.day > $1.day }
    }

    private func metadata(_ item: Transcription, date: Date, count: Int) -> String {
        var parts = [item.compactModelLabel, item.languageLabel]
        if let duration = item.durationSeconds {
            let seconds = max(0, Int(duration))
            parts.append(String(format: "%d:%02d", seconds / 60, seconds % 60))
        }
        parts.append(date.formatted(.dateTime.hour().minute()))
        if count > 1 { parts.append("\(count)v") }
        return parts.joined(separator: " · ")
    }

    private func dayLabel(_ day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "Today" }
        if Calendar.current.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.month(.abbreviated).day())
    }
}
