enum ExploreMode: String, CaseIterable, Identifiable {
    case list = "List"
    case calendar = "Calendar"
    case places = "Places"

    var id: String { rawValue }
}
