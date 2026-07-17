enum ExploreMode: String {
    case calendar = "Calendar"
    case places = "Places"

    var systemImage: String {
        switch self {
        case .calendar: "calendar"
        case .places: "mappin.and.ellipse"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .calendar: "calendar-screen"
        case .places: "places-screen"
        }
    }
}
