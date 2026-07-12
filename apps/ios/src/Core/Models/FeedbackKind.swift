enum FeedbackKind: String, Codable, Hashable {
    case saved
    case seen
    case moreLikeThis = "more_like_this"
    case lessLikeThis = "less_like_this"
    case tooBasic = "too_basic"
}
