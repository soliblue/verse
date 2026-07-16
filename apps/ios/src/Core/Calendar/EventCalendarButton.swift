import SwiftUI
import UIKit

struct EventCalendarButton: View {
    @Environment(\.openURL) private var openURL
    let event: EventItem
    let calendar: CalendarRepository
    @State private var editor: CalendarEditorRequest?
    @State private var prompt: Prompt?
    @State private var refreshID = UUID()

    var body: some View {
        Button {
            switch state {
            case .updated: prompt = .updated
            case .cancelled: prompt = .cancelled
            case .ended: return
            case .notAdded, .linked: Task { await openEditor() }
            }
        } label: {
            Label(state.title, systemImage: state.systemImage)
        }
        .id(refreshID)
        .disabled(state == .ended)
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
            switch prompt {
            case .denied:
                Button("Settings") {
                    openURL(URL(string: UIApplication.openSettingsURLString)!)
                }
                Button("Open official event") { openURL(event.officialURL) }
                Button("Cancel", role: .cancel) {}
            case .updated:
                Button("Review update") { Task { await openEditor() } }
                Button("Leave unchanged", role: .cancel) {}
            case .cancelled:
                Button("View calendar entry") { Task { await openEditor() } }
                Button("Leave unchanged", role: .cancel) {}
            case .unresolved:
                Button("Open Calendar") { openCalendar() }
                Button("Cancel", role: .cancel) {}
            case nil:
                Button("OK", role: .cancel) {}
            }
        } message: {
            Text(prompt?.message ?? "")
        }
    }

    private var state: CalendarLinkState {
        calendar.state(for: event)
    }

    private var promptBinding: Binding<Bool> {
        Binding(
            get: { prompt != nil },
            set: { if !$0 { prompt = nil } }
        )
    }

    private func openEditor() async {
        switch await calendar.prepare(event) {
        case .ready(let request): editor = request
        case .denied: prompt = .denied
        case .unresolved: prompt = .unresolved
        }
    }

    private func openCalendar() {
        guard
            let date = event.occurrence.startDate,
            let url = URL(string: "calshow:\(date.timeIntervalSinceReferenceDate)")
        else { return }
        openURL(url)
    }

    private enum Prompt {
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
