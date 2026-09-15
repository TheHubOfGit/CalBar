import Foundation

public final class GoogleCalendarService: Sendable {
    public static let shared = GoogleCalendarService()

    private init() {}

    public func fetchCalendarList(accessToken: String) async throws -> [CalendarItem] {
        guard let url = URL(string: "https://www.googleapis.com/calendar/v3/users/me/calendarList") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown server response"
            throw NSError(domain: "GoogleCalendarService", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else {
            return []
        }

        return items.compactMap { item in
            guard let id = item["id"] as? String,
                  let summary = item["summary"] as? String else {
                return nil
            }
            let bgColor = item["backgroundColor"] as? String ?? "#1a73e8"
            let isPrimary = item["primary"] as? Bool ?? false
            let accessRole = item["accessRole"] as? String
            let isSelected = item["selected"] as? Bool ?? true

            return CalendarItem(
                id: id,
                summary: summary,
                colorHex: bgColor,
                isSelected: isSelected,
                isPrimary: isPrimary,
                accessRole: accessRole
            )
        }
    }

    public func fetchEvents(calendarId: String, start: Date, end: Date, calendarColorHex: String?, accessToken: String) async throws -> [CalendarEvent] {
        let escapedId = calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendarId
        let isoFormatter = DateFormatterCache.iso8601
        let dayDateFormatter = DateFormatterCache.dayKey

        var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/\(escapedId)/events")!
        components.queryItems = [
            URLQueryItem(name: "timeMin", value: isoFormatter.string(from: start)),
            URLQueryItem(name: "timeMax", value: isoFormatter.string(from: end)),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
            URLQueryItem(name: "maxResults", value: "250")
        ]

        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Failed to fetch events"
            throw NSError(domain: "GoogleCalendarService", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else {
            return []
        }

        return items.compactMap { item -> CalendarEvent? in
            guard let id = item["id"] as? String else { return nil }

            let summary = item["summary"] as? String ?? "(No title)"
            let description = item["description"] as? String
            let location = item["location"] as? String
            let status = item["status"] as? String
            if status == "cancelled" { return nil }

            let eventColorId = item["colorId"] as? String
            let hangoutLink = item["hangoutLink"] as? String
            let htmlLink = item["htmlLink"] as? String

            var attendeeNames: [String] = []
            if let attendeesRaw = item["attendees"] as? [[String: Any]] {
                attendeeNames = attendeesRaw.compactMap { att in
                    att["displayName"] as? String ?? att["email"] as? String
                }
            }

            var startDate: Date?
            var endDate: Date?
            var isAllDay = false

            if let startObj = item["start"] as? [String: Any] {
                if let dtString = startObj["dateTime"] as? String {
                    startDate = isoFormatter.date(from: dtString)
                } else if let dString = startObj["date"] as? String {
                    startDate = dayDateFormatter.date(from: dString)
                    isAllDay = true
                }
            }

            if let endObj = item["end"] as? [String: Any] {
                if let dtString = endObj["dateTime"] as? String {
                    endDate = isoFormatter.date(from: dtString)
                } else if let dString = endObj["date"] as? String {
                    endDate = dayDateFormatter.date(from: dString)
                }
            }

            guard let sDate = startDate else { return nil }
            let eDate = endDate ?? sDate.addingTimeInterval(3600)

            return CalendarEvent(
                id: id,
                calendarId: calendarId,
                calendarColorHex: calendarColorHex,
                eventColorId: eventColorId,
                summary: summary,
                description: description,
                location: location,
                start: sDate,
                end: eDate,
                isAllDay: isAllDay,
                hangoutLink: hangoutLink,
                htmlLink: htmlLink,
                status: status,
                attendees: attendeeNames
            )
        }
    }
}
