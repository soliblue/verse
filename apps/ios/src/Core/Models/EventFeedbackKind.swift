enum EventFeedbackKind: String, Codable, CaseIterable, Hashable {
    case interested
    case going
    case attended
    case loved
    case notForMe = "not_for_me"
    case tooFar = "too_far"
    case tooExpensive = "too_expensive"
    case soldOut = "sold_out"
    case moreFromVenue = "more_from_venue"
    case moreLikeThis = "more_like_this"
}
