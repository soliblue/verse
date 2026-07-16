enum AppTab: CaseIterable, Hashable {
    case today
    case explore
    case library
    case topics
    case settings

    var title: String {
        switch self {
        case .today: "Today"
        case .explore: "Explore"
        case .library: "Library"
        case .topics: "Topics"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "square.stack.3d.up"
        case .explore: "sparkles"
        case .library: "bookmark"
        case .topics: "scope"
        case .settings: "slider.horizontal.3"
        }
    }
}
