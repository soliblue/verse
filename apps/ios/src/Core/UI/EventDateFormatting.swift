import Foundation

enum EventDateFormatting {
    static let berlin = TimeZone(identifier: "Europe/Berlin")!

    static func day(_ value: String) -> String {
        guard let date = TimestampParsing.date(value) else { return value }
        return formatter("EEE, MMM d").string(from: date)
    }

    static func time(_ value: String) -> String {
        guard let date = TimestampParsing.date(value) else { return value }
        return formatter("HH:mm").string(from: date)
    }

    static func full(_ value: String) -> String {
        guard let date = TimestampParsing.date(value) else { return value }
        return formatter("EEEE, MMMM d · HH:mm").string(from: date)
    }

    static func dayKey(_ date: Date) -> String {
        formatter("yyyy-MM-dd").string(from: date)
    }

    static func dayKey(_ value: String) -> String? {
        TimestampParsing.date(value).map(dayKey)
    }

    static func horizonDate(_ value: String) -> Date? {
        formatter("yyyy-MM-dd").date(from: value)
    }

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        calendar.timeZone = berlin
        return calendar
    }

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = berlin
        formatter.dateFormat = format
        return formatter
    }
}
