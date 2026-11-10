import Foundation
import SwiftUI

public struct CalendarEvent: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let calendarId: String
    public var calendarColorHex: String?
    public var eventColorId: String?
    public var summary: String
    public var description: String?
    public var location: String?
    public var start: Date
    public var end: Date
    public var isAllDay: Bool
    public var hangoutLink: String?
    public var htmlLink: String?
    public var status: String?
    public var attendees: [String]

    public init(
        id: String,
        calendarId: String,
        calendarColorHex: String? = nil,
        eventColorId: String? = nil,
        summary: String,
        description: String? = nil,
        location: String? = nil,
        start: Date,
        end: Date,
        isAllDay: Bool = false,
        hangoutLink: String? = nil,
        htmlLink: String? = nil,
        status: String? = "confirmed",
        attendees: [String] = []
    ) {
        self.id = id
        self.calendarId = calendarId
        self.calendarColorHex = calendarColorHex
        self.eventColorId = eventColorId
        self.summary = summary
        self.description = description
        self.location = location
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.hangoutLink = hangoutLink
        self.htmlLink = htmlLink
        self.status = status
        self.attendees = attendees
    }

    public var durationMinutes: Double {
        max(15, end.timeIntervalSince(start) / 60.0)
    }

    public var startMinuteOfDay: Double {
        start.minuteOfDay
    }

    public var endMinuteOfDay: Double {
        let raw = end.minuteOfDay
        // If an event ends at midnight the next day
        if raw == 0 && end > start {
            return 24 * 60
        }
        return raw
    }

    public var resolvedHex: String {
        GooglePalette.hex(forEventColorId: eventColorId, calendarHex: calendarColorHex)
    }

    public var resolvedColor: Color {
        Color.cached(hex: resolvedHex)
    }

    public var contrastTextColor: Color {
        Color.isColorDarkCached(hex: resolvedHex) ? .white : Color(white: 0.12)
    }

    public var timeRangeString: String {
        if isAllDay {
            return "All Day"
        }
        return "\(start.formattedTime()) – \(end.formattedTime())"
    }

    public var isHappeningNow: Bool {
        let now = Date()
        return now >= start && now <= end
    }

    public var isUpcoming: Bool {
        start > Date()
    }

    public var isPassed: Bool {
        if isAllDay {
            return start < Date().startOfDay()
        }
        return end <= Date()
    }
}
