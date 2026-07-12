enum FeedbackPreference: String, Codable, CaseIterable, Hashable {
    case moreLikeThis = "more_like_this"
    case lessLikeThis = "less_like_this"
    case tooBasic = "too_basic"
}
