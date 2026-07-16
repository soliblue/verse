import SwiftUI

struct ExploreListView: View {
    let sections: [EventSection]
    let attendedEvents: [EventItem]
    let calendar: CalendarRepository

    var body: some View {
        List {
            if sections.isEmpty {
                ContentUnavailableView(
                    "Nothing live right now",
                    systemImage: "sparkles",
                    description: Text("Nightjar will look again tonight.")
                )
                .listRowBackground(VerseTheme.paper)
            }
            ForEach(sections) { section in
                Section(section.title) {
                    ForEach(section.events) { event in
                        EventRowView(event: event, calendar: calendar)
                            .listRowBackground(VerseTheme.paper)
                    }
                }
            }
            if !attendedEvents.isEmpty {
                Section("Attended") {
                    ForEach(attendedEvents) { event in
                        EventRowView(event: event, calendar: calendar)
                            .listRowBackground(VerseTheme.paper)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}
