import Foundation

enum HTTPResult {
    case success(Data)
    case transportFailure
    case httpFailure(Int)
}
