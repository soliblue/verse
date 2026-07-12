enum TopicKind: String, Codable, CaseIterable, Hashable, Identifiable {
    case interest
    case lab
    case artist
    case source
    case venue
    case exclusion

    var id: String { rawValue }

    var label: String {
        switch self {
        case .interest: "Interest"
        case .lab: "Lab"
        case .artist: "Artist"
        case .source: "Source"
        case .venue: "Venue"
        case .exclusion: "Exclusion"
        }
    }

    var systemImage: String {
        switch self {
        case .interest: "sparkles"
        case .lab: "building.2"
        case .artist: "person.crop.square"
        case .source: "newspaper"
        case .venue: "mappin.and.ellipse"
        case .exclusion: "minus.circle"
        }
    }
}
