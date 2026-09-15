import Foundation

public enum SampleDataService {
    public static func sampleCalendars() -> [CalendarItem] {
        return [
            CalendarItem(id: "work", summary: "Work & Projects", colorHex: "#039be5", isSelected: true, isPrimary: true),
            CalendarItem(id: "personal", summary: "Personal", colorHex: "#33b679", isSelected: true, isPrimary: false),
            CalendarItem(id: "team", summary: "Design & Product", colorHex: "#8e24aa", isSelected: true, isPrimary: false),
            CalendarItem(id: "reminders", summary: "Deadlines & Reminders", colorHex: "#e67c73", isSelected: true, isPrimary: false)
        ]
    }

    public static func sampleEvents(for date: Date = Date()) -> [CalendarEvent] {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)

        func makeDate(hour: Int, minute: Int) -> Date {
            cal.date(bySettingHour: hour, minute: minute, second: 0, of: startOfDay)!
        }

        return [
            CalendarEvent(
                id: "sample-all-day-1",
                calendarId: "work",
                calendarColorHex: "#039be5",
                summary: "🚀 Q3 Sprint Kickoff",
                description: "Quarterly sprint planning with engineering and product leaders.",
                start: startOfDay,
                end: startOfDay,
                isAllDay: true
            ),
            CalendarEvent(
                id: "sample-1",
                calendarId: "work",
                calendarColorHex: "#039be5",
                summary: "Daily Team Standup",
                description: "Quick 15-minute sync on blockers and daily priorities.",
                location: "Virtual",
                start: makeDate(hour: 9, minute: 0),
                end: makeDate(hour: 9, minute: 30),
                hangoutLink: "https://meet.google.com/abc-defg-hij",
                attendees: ["Alex Rivers", "Sarah Chen", "Jordan Taylor"]
            ),
            CalendarEvent(
                id: "sample-2",
                calendarId: "team",
                calendarColorHex: "#8e24aa",
                summary: "CalBar Architecture Review",
                description: "Deep dive into menu bar popover dynamics and EventKit sync.",
                location: "Conference Room B / Meet",
                start: makeDate(hour: 10, minute: 0),
                end: makeDate(hour: 11, minute: 30),
                hangoutLink: "https://meet.google.com/xyz-uvwx-rst",
                attendees: ["Tech Lead", "Security Auditor", "Frontend Architect"]
            ),
            CalendarEvent(
                id: "sample-3",
                calendarId: "work",
                calendarColorHex: "#039be5",
                summary: "Sync with Product Manager",
                description: "Reviewing Q3 roadmap and feedback on Google Calendar layout.",
                start: makeDate(hour: 11, minute: 0),
                end: makeDate(hour: 12, minute: 0),
                hangoutLink: "https://meet.google.com/pqr-stuv-wxy",
                attendees: ["Product Lead"]
            ),
            CalendarEvent(
                id: "sample-4",
                calendarId: "personal",
                calendarColorHex: "#33b679",
                summary: "🥗 Lunch & Walk",
                location: "Downtown Cafe",
                start: makeDate(hour: 12, minute: 30),
                end: makeDate(hour: 13, minute: 30)
            ),
            CalendarEvent(
                id: "sample-5",
                calendarId: "team",
                calendarColorHex: "#8e24aa",
                summary: "Google Meet: Design Critique",
                description: "Figma walkthrough for macOS menu bar popover interactions.",
                start: makeDate(hour: 14, minute: 0),
                end: makeDate(hour: 15, minute: 0),
                hangoutLink: "https://meet.google.com/des-crit-123",
                attendees: ["Design Guild"]
            ),
            CalendarEvent(
                id: "sample-6",
                calendarId: "reminders",
                calendarColorHex: "#e67c73",
                summary: "Code Review & PR Merge",
                description: "Review CalBar PR #42 and tag v1.0.0 release.",
                start: makeDate(hour: 16, minute: 0),
                end: makeDate(hour: 17, minute: 0)
            )
        ]
    }
}
