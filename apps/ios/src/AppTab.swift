enum AppTab: CaseIterable, Hashable {
    case articles
    case calendar
    case places
    case library
    case settings

    var title: String {
        switch self {
        case .articles: "Articles"
        case .calendar: "Calendar"
        case .places: "Places"
        case .library: "Library"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .articles: "doc.text.image"
        case .calendar: "calendar"
        case .places: "mappin.and.ellipse"
        case .library: "bookmark"
        case .settings: "slider.horizontal.3"
        }
    }
}
