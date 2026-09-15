import Foundation
import EventKit
import SwiftUI
import AppKit

@MainActor
public final class EventKitService: ObservableObject {
    public static let shared = EventKitService()

    @Published public var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published public var hasAccess: Bool = false

    private var eventStore = EKEventStore()

    private init() {
        checkAuthorization()
    }

    public var isRunningInAppBundle: Bool {
        guard let bundleId = Bundle.main.bundleIdentifier, !bundleId.isEmpty else {
            return false
        }
        return !Bundle.main.bundlePath.contains(".build")
    }

    public func checkAuthorization() {
        let status = EKEventStore.authorizationStatus(for: .event)
        self.authorizationStatus = status
        if #available(macOS 14.0, *) {
            self.hasAccess = (status == .fullAccess)
        } else {
            self.hasAccess = (status == .authorized)
        }
    }

    public func requestAccess() async -> Bool {
        do {
            let granted: Bool
            if #available(macOS 14.0, *) {
                granted = try await eventStore.requestFullAccessToEvents()
            } else {
                granted = try await eventStore.requestAccess(to: .event)
            }
            if granted {
                // Important: Reinitialize EKEventStore so it acquires the freshly granted access rights
                self.eventStore = EKEventStore()
            }
            checkAuthorization()
            return granted
        } catch {
            checkAuthorization()
            return false
        }
    }

    public func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    public func fetchCalendars() -> [CalendarItem] {
        let ekCalendars = eventStore.calendars(for: .event)
        return ekCalendars.map { cal in
            let hex = cal.color.hexString
            return CalendarItem(
                id: cal.calendarIdentifier,
                summary: cal.title,
                colorHex: hex,
                isSelected: true,
                isPrimary: cal.isSubscribed == false && cal.type != .birthday,
                accessRole: cal.allowsContentModifications ? "owner" : "reader"
            )
        }
    }

    public func fetchEvents(calendarIds: [String], start: Date, end: Date) -> [CalendarEvent] {
        let allCals = eventStore.calendars(for: .event)
        let selectedCals = allCals.filter { calendarIds.contains($0.calendarIdentifier) }
        guard !selectedCals.isEmpty else { return [] }

        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: selectedCals)
        let ekEvents = eventStore.events(matching: predicate)

        return ekEvents.map { event in
            var meetLink: String? = nil
            // Check URL or notes for Meet / Zoom link
            if let urlStr = event.url?.absoluteString, urlStr.contains("meet.google.com") || urlStr.contains("zoom.us") {
                meetLink = urlStr
            } else if let notes = event.notes {
                if let range = notes.range(of: "https://meet.google.com/[a-zA-Z0-9-]+", options: .regularExpression) {
                    meetLink = String(notes[range])
                } else if let range = notes.range(of: "https://[a-zA-Z0-9.]*zoom.us/j/[0-9]+", options: .regularExpression) {
                    meetLink = String(notes[range])
                }
            }

            let attendees = event.attendees?.compactMap { $0.name ?? $0.url.absoluteString } ?? []

            return CalendarEvent(
                id: event.eventIdentifier ?? UUID().uuidString,
                calendarId: event.calendar.calendarIdentifier,
                calendarColorHex: event.calendar.color.hexString,
                eventColorId: nil,
                summary: event.title ?? "(No title)",
                description: event.notes,
                location: event.location,
                start: event.startDate,
                end: event.endDate,
                isAllDay: event.isAllDay,
                hangoutLink: meetLink,
                htmlLink: event.url?.absoluteString,
                status: "confirmed",
                attendees: attendees
            )
        }
    }
}

private extension NSColor {
    var hexString: String {
        if let srgb = self.usingColorSpace(.sRGB) {
            let r = Int(round(srgb.redComponent * 255.0))
            let g = Int(round(srgb.greenComponent * 255.0))
            let b = Int(round(srgb.blueComponent * 255.0))
            return String(format: "#%02X%02X%02X", r, g, b)
        }
        if let dev = self.usingColorSpace(.deviceRGB) {
            let r = Int(round(dev.redComponent * 255.0))
            let g = Int(round(dev.greenComponent * 255.0))
            let b = Int(round(dev.blueComponent * 255.0))
            return String(format: "#%02X%02X%02X", r, g, b)
        }
        return "#1a73e8"
    }
}
