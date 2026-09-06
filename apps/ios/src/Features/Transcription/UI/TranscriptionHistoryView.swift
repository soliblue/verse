import SwiftUI

struct TranscriptionHistoryView: View {
    @Bindable var store: TranscriptionStore
    let minimumHeight: CGFloat
    private let green = Color(red: 0, green: 0.39, blue: 0.22)

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("RECENT TRANSCRIPTS").font(.system(size: 12, weight: .bold)).tracking(0.3)
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
            Divider().overlay(green.opacity(0.4))
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
                .disabled(store.isUploading || store.recorder.isRecording)
                Divider().overlay(green.opacity(0.25))
            }
            ForEach(store.items) { item in
                NavigationLink(value: item.id) {
                    HStack(alignment: .center, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.title).font(.system(size: 17, weight: .medium)).lineLimit(3)
                            if item.isPending {
                                HStack {
                                    ProgressView().controlSize(.mini)
                                    Text(item.state == "queued" ? "Queued" : "Transcribing").font(.caption)
                                }
                            } else if item.state == "failed" {
                                Text("Failed").font(.caption).foregroundStyle(.red)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(item.date, format: .dateTime.hour().minute())
                            if !Calendar.current.isDateInToday(item.date) {
                                Text(item.date, format: .dateTime.month(.abbreviated).day())
                            }
                        }
                        .font(.caption.monospacedDigit()).foregroundStyle(green)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold)).foregroundStyle(green)
                    }
                    .padding(.vertical, 18).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Delete", role: .destructive) { store.perform { try await store.delete(item) } }
                }
                Divider().overlay(green.opacity(0.25))
            }
            Color.clear.frame(height: 30).accessibilityHidden(true)
        }
        .frame(minHeight: minimumHeight, alignment: .top)
        .padding(.leading, 42).padding(.trailing, 26).padding(.top, 18).padding(.bottom, 24)
        .background {
            Image("CitrusReceipt").resizable(capInsets: EdgeInsets(top: 30, leading: 34, bottom: 34, trailing: 30))
                .mask { Rectangle().padding(8).blur(radius: 6) }
                .accessibilityHidden(true)
        }
    }
}
