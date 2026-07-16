import SwiftUI

struct EventFeedbackBar: View {
    let event: EventItem
    let repository: EventFeedbackRepository
    @State private var state: CachedEventFeedbackState?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                feedbackButton("Interested", icon: "star", kind: .interested, active: state?.interested)
                feedbackButton("Going", icon: "figure.walk", kind: .going, active: state?.going)
            }
            HStack(spacing: 8) {
                feedbackButton("Attended", icon: "checkmark", kind: .attended, active: state?.attended)
                feedbackButton("Loved", icon: "heart", kind: .loved, active: state?.loved)
            }
        }
        .task {
            state = repository.state(
                eventID: event.id,
                occurrenceID: event.occurrence.id
            )
        }
    }

    private func feedbackButton(
        _ title: String,
        icon: String,
        kind: EventFeedbackKind,
        active: Bool?
    ) -> some View {
        Button {
            Task {
                state = await repository.update(
                    eventID: event.id,
                    occurrenceID: event.occurrence.id,
                    kind: kind,
                    value: active != true
                )
            }
        } label: {
            Label(title, systemImage: active == true ? "\(icon).fill" : icon)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(VerseTheme.ink)
    }
}
