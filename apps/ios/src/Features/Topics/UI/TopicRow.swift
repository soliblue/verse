import SwiftUI

struct TopicRow: View {
    let topic: Topic
    let isDisabled: Bool
    let onToggle: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: topic.kind.systemImage)
                .foregroundStyle(topic.kind == .exclusion ? .red : VerseTheme.blue)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(topic.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(VerseTheme.ink)
                if !topic.description.isEmpty {
                    Text(topic.description)
                        .font(.caption)
                        .foregroundStyle(VerseTheme.secondaryInk)
                        .lineLimit(2)
                }
                Text(topic.kind.label)
                    .font(.caption2)
                    .foregroundStyle(VerseTheme.secondaryInk)
            }
            Spacer()
            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil")
                    .foregroundStyle(VerseTheme.secondaryInk)
            }
            .buttonStyle(.borderless)
            .disabled(isDisabled)
            .accessibilityLabel("Edit \(topic.name)")
            Toggle("", isOn: Binding(get: { topic.isEnabled }, set: { _ in onToggle() }))
                .labelsHidden()
                .disabled(isDisabled)
                .accessibilityLabel("Enable \(topic.name)")
        }
        .padding(.vertical, 4)
    }
}
