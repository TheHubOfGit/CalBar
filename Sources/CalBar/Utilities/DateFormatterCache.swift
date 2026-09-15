import Foundation

/// High-performance thread-safe cached DateFormatters to eliminate heap allocation churn during renders
public final class DateFormatterCache: @unchecked Sendable {
    public static let shared = DateFormatterCache()

    public static let monthYear: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MMMM yyyy"
        return df
    }()

    public static let dayHeader: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEE, MMM d"
        return df
    }()

    public static let dayNumber: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "d"
        return df
    }()

    public static let weekdayShort: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEE"
        return df
    }()

    public static let timeShort: DateFormatter = {
        let df = DateFormatter()
        df.timeStyle = .short
        return df
    }()

    public static let hourGutter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "h a"
        return df
    }()

    nonisolated(unsafe) public static let iso8601: ISO8601DateFormatter = {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        return iso
    }()

    public static let dayKey: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = .current
        return df
    }()
}
