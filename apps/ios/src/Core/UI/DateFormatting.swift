import Foundation

enum DateFormatting {
    static func editionDate(_ value: String) -> String {
        guard let date = DateFormatter.isoDay.date(from: value) else { return value }
        return date.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
    }

    static func shortDate(_ value: String) -> String {
        guard let date = TimestampParsing.date(value) else { return value }
        return date.formatted(.dateTime.month(.abbreviated).day().year())
    }
}

private extension DateFormatter {
    static let isoDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
