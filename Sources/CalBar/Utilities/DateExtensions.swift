import Foundation

extension Date {
    public func startOfDay(using calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: self)
    }

    public func endOfDay(using calendar: Calendar = .current) -> Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return calendar.date(byAdding: components, to: startOfDay(using: calendar)) ?? self
    }

    public func addingDays(_ days: Int, using calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: days, to: self) ?? self
    }

    public func startOfWeek(firstWeekday: Int = 1, using calendar: Calendar = .current) -> Date {
        var cal = calendar
        cal.firstWeekday = firstWeekday
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return cal.date(from: components) ?? self
    }

    public func daysOfWeek(firstWeekday: Int = 1, using calendar: Calendar = .current) -> [Date] {
        let start = startOfWeek(firstWeekday: firstWeekday, using: calendar)
        return (0..<7).compactMap { start.addingDays($0, using: calendar) }
    }

    public func isSameDay(as other: Date, using calendar: Calendar = .current) -> Bool {
        calendar.isDate(self, inSameDayAs: other)
    }

    public var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    public var minuteOfDay: Double {
        let components = Calendar.current.dateComponents([.hour, .minute], from: self)
        let hour = Double(components.hour ?? 0)
        let minute = Double(components.minute ?? 0)
        return hour * 60 + minute
    }

    public var dayKeyString: String {
        DateFormatterCache.dayKey.string(from: self)
    }

    public func formattedMonthYear() -> String {
        DateFormatterCache.monthYear.string(from: self)
    }

    public func formattedDayHeader() -> String {
        DateFormatterCache.dayHeader.string(from: self)
    }

    public func formattedDayNumber() -> String {
        DateFormatterCache.dayNumber.string(from: self)
    }

    public func formattedWeekdayShort() -> String {
        DateFormatterCache.weekdayShort.string(from: self).uppercased()
    }

    public func formattedTime() -> String {
        DateFormatterCache.timeShort.string(from: self)
    }

    public func formattedHourGutter() -> String {
        DateFormatterCache.hourGutter.string(from: self)
    }
}
