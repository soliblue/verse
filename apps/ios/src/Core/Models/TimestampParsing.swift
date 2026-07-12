import Foundation

enum TimestampParsing {
    static func date(_ value: String?) -> Date? {
        guard let value else { return nil }
        return try? Date.ISO8601FormatStyle(includingFractionalSeconds: value.contains(".")).parse(value)
    }
}
