enum CalendarLinkState: Equatable {
    case notAdded
    case linked
    case updated
    case cancelled
    case ended

    var title: String {
        switch self {
        case .notAdded: "Add to Calendar"
        case .linked: "View in Calendar"
        case .updated: "Event updated"
        case .cancelled: "Event cancelled"
        case .ended: "Event ended"
        }
    }

    var systemImage: String {
        switch self {
        case .notAdded: "calendar.badge.plus"
        case .linked: "calendar"
        case .updated: "calendar.badge.exclamationmark"
        case .cancelled: "exclamationmark.triangle"
        case .ended: "clock"
        }
    }
}
