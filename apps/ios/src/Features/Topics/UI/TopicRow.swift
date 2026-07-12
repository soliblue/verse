import SwiftUI

struct TopicRow: View {
    let topic: Topic
    let isDisabled: Bool
    let onToggle: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: topic.kind.systemImage)
                .foregroundStyle(topic.kind == .exclusion ? .red : MorrowTheme.blue)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(topic.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(MorrowTheme.ink)
                if !topic.description.isEmpty {
                    Text(topic.description)
                        .font(.caption)
                        .foregroundStyle(MorrowTheme.secondaryInk)
                        .lineLimit(2)
                }
                Text(topic.kind.label)
                    .font(.caption2)
                    .foregroundStyle(MorrowTheme.secondaryInk)
            }
            Spacer()
            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil")
                    .foregroundStyle(MorrowTheme.secondaryInk)
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
