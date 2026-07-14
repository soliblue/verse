import Foundation

enum DateFormatting {
    static func editionDate(_ value: String) -> String {
        guard let date = DateFormatter.isoDay.date(from: value) else { return value }
        return DateFormatter.englishFull.string(from: date)
    }

    static func shortDate(_ value: String) -> String {
        guard let date = TimestampParsing.date(value) else { return value }
        return DateFormatter.englishShort.string(from: date)
    }

    static func dateTime(_ date: Date) -> String {
        DateFormatter.englishDateTime.string(from: date)
    }
}

private extension DateFormatter {
    static let isoDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    static let englishFull: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter
    }()

    static let englishShort: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    static let englishDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
