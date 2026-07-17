import SwiftUI

struct EventDetailView: View {
    let event: EventItem
    let feedback: EventFeedbackRepository
    let calendar: CalendarRepository

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(event.title)
                    .font(.display(38))
                    .foregroundStyle(VerseTheme.ink)
                    .accessibilityIdentifier("event-detail")

                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    Text(EventDateFormatting.time(event.occurrence.startAt))
                    Spacer(minLength: 8)
                    if let routeURL {
                        Link(event.venue.name, destination: routeURL)
                            .multilineTextAlignment(.trailing)
                    } else {
                        Text(event.venue.name)
                            .multilineTextAlignment(.trailing)
                    }
                }
                .font(.utility(13))
                .foregroundStyle(VerseTheme.secondaryInk)
                .padding(.top, 14)

                Text(event.description)
                    .font(.reading(18))
                    .foregroundStyle(VerseTheme.ink)
                    .lineSpacing(6)
                    .textSelection(.enabled)
                    .padding(.top, 28)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 64)
        }
        .background(VerseTheme.paper)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EventActionsMenu(
                    event: event,
                    feedback: feedback,
                    calendar: calendar,
                    routeURL: routeURL
                )
            }
        }
    }

    private var routeURL: URL? {
        let destination = event.venue.address ?? event.venue.name
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [URLQueryItem(name: "daddr", value: destination)]
        return components?.url
    }
}
