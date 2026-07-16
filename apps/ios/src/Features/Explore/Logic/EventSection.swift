struct EventSection: Identifiable {
    let title: String
    let events: [EventItem]

    var id: String { title }
}
