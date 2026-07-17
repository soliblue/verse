import SwiftUI
import UIKit

struct EventActionsMenu: View {
    @Environment(\.openURL) private var openURL
    let event: EventItem
    let feedback: EventFeedbackRepository
    let calendar: CalendarRepository
    let routeURL: URL?
    @State private var feedbackState: CachedEventFeedbackState?
    @State private var editor: CalendarEditorRequest?
    @State private var prompt: CalendarPrompt?
    @State private var refreshID = UUID()

    var body: some View {
        Menu {
            Button {
                openCalendarEditor()
            } label: {
                Label(calendarState.title, systemImage: calendarState.systemImage)
            }
            .disabled(calendarState == .ended)

            if let routeURL {
                Link(destination: routeURL) {
                    Label("Route", systemImage: "arrow.triangle.turn.up.right.diamond")
                }
            }

            if let bookingURL = event.bookingURL ?? event.occurrence.bookingURL {
                Link(destination: bookingURL) {
                    Label(
                        event.occurrence.rsvpRequired ? "Reserve" : "Book",
                        systemImage: "ticket"
                    )
                }
            }

            Link(destination: event.officialURL) {
                Label("Official event", systemImage: "arrow.up.right")
            }

            Divider()

            Menu {
                toggleButton("Interested", icon: "star", kind: .interested)
                toggleButton("Going", icon: "figure.walk", kind: .going)
                toggleButton("Attended", icon: "checkmark", kind: .attended)
                toggleButton("Loved", icon: "heart", kind: .loved)
                Divider()
                signalButton("Not for me", icon: "xmark", kind: .notForMe)
                signalButton("Too far", icon: "location.slash", kind: .tooFar)
                signalButton("Too expensive", icon: "eurosign", kind: .tooExpensive)
                signalButton("Sold out", icon: "ticket", kind: .soldOut)
                signalButton("More from this venue", icon: "building.2", kind: .moreFromVenue)
                signalButton("More like this", icon: "plus", kind: .moreLikeThis)
            } label: {
                Label("Feedback", systemImage: "slider.horizontal.3")
            }
        } label: {
            Image(systemName: "ellipsis")
                .accessibilityLabel("Event actions")
        }
        .accessibilityIdentifier("event-actions")
        .id(refreshID)
        .sheet(item: $editor) { request in
            CalendarEventEditor(
                request: request,
                eventStore: calendar.eventStore
            ) { saved in
                if saved { calendar.record(request) }
                editor = nil
                refreshID = UUID()
            }
            .ignoresSafeArea()
        }
        .alert(prompt?.title ?? "Calendar", isPresented: promptBinding) {
            calendarAlertActions
        } message: {
            Text(prompt?.message ?? "")
        }
        .task {
            feedbackState = feedback.state(
                eventID: event.id,
                occurrenceID: event.occurrence.id
            )
        }
    }

    private var calendarState: CalendarLinkState {
        calendar.state(for: event)
    }

    private var promptBinding: Binding<Bool> {
        Binding(
            get: { prompt != nil },
            set: { if !$0 { prompt = nil } }
        )
    }

    @ViewBuilder
    private var calendarAlertActions: some View {
        switch prompt {
        case .denied:
            Button("Settings") {
                openURL(URL(string: UIApplication.openSettingsURLString)!)
            }
            Button("Open official event") { openURL(event.officialURL) }
            Button("Cancel", role: .cancel) {}
        case .updated:
            Button("Review update") { Task { await prepareCalendarEditor() } }
            Button("Leave unchanged", role: .cancel) {}
        case .cancelled:
            Button("View calendar entry") { Task { await prepareCalendarEditor() } }
            Button("Leave unchanged", role: .cancel) {}
        case .unresolved:
            Button("Open Calendar") { openCalendarApp() }
            Button("Cancel", role: .cancel) {}
        case nil:
            Button("OK", role: .cancel) {}
        }
    }

    private func toggleButton(
        _ title: String,
        icon: String,
        kind: EventFeedbackKind
    ) -> some View {
        let selected = isSelected(kind)
        return Button {
            update(kind, value: !selected)
        } label: {
            Label(title, systemImage: selected ? "checkmark" : icon)
        }
    }

    private func signalButton(
        _ title: String,
        icon: String,
        kind: EventFeedbackKind
    ) -> some View {
        Button {
            update(kind, value: true)
        } label: {
            Label(title, systemImage: icon)
        }
    }

    private func isSelected(_ kind: EventFeedbackKind) -> Bool {
        switch kind {
        case .interested: feedbackState?.interested == true
        case .going: feedbackState?.going == true
        case .attended: feedbackState?.attended == true
        case .loved: feedbackState?.loved == true
        case .notForMe, .tooFar, .tooExpensive, .soldOut:
            feedbackState?.dismissed == true
        case .moreFromVenue, .moreLikeThis:
            feedbackState?.interested == true
        }
    }

    private func update(_ kind: EventFeedbackKind, value: Bool) {
        Task {
            feedbackState = await feedback.update(
                eventID: event.id,
                occurrenceID: event.occurrence.id,
                kind: kind,
                value: value
            )
        }
    }

    private func openCalendarEditor() {
        switch calendarState {
        case .updated: prompt = .updated
        case .cancelled: prompt = .cancelled
        case .ended: return
        case .notAdded, .linked: Task { await prepareCalendarEditor() }
        }
    }

    private func prepareCalendarEditor() async {
        switch await calendar.prepare(event) {
        case .ready(let request): editor = request
        case .denied: prompt = .denied
        case .unresolved: prompt = .unresolved
        }
    }

    private func openCalendarApp() {
        guard
            let date = event.occurrence.startDate,
            let url = URL(string: "calshow:\(date.timeIntervalSinceReferenceDate)")
        else { return }
        openURL(url)
    }

    private enum CalendarPrompt {
        case denied
        case updated
        case cancelled
        case unresolved

        var title: String {
            switch self {
            case .denied: "Calendar access is off"
            case .updated: "Event details changed"
            case .cancelled: "Event cancelled"
            case .unresolved: "Already added"
            }
        }

        var message: String {
            switch self {
            case .denied: "Allow Calendar access to review and save this event."
            case .updated: "Review the new details before changing your calendar event."
            case .cancelled: "Verse will never delete your calendar entry automatically."
            case .unresolved:
                "Verse recorded this export, but Calendar did not return an identifier. "
                    + "Open Calendar to find it. Verse will not create a duplicate."
            }
        }
    }
}
