enum AppTab: CaseIterable, Hashable {
    case articles
    case calendar

    var title: String {
        switch self {
        case .articles: "Articles"
        case .calendar: "Calendar"
        }
    }

    var systemImage: String {
        switch self {
        case .articles: "doc.text.image"
        case .calendar: "calendar"
        }
    }
}
