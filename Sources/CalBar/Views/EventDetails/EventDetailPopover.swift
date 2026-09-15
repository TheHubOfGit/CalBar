import SwiftUI

public struct EventDetailPopover: View {
    public let event: CalendarEvent
    public let onClose: () -> Void

    public init(event: CalendarEvent, onClose: @escaping () -> Void) {
        self.event = event
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header: Color bar & Close button
            HStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(event.resolvedColor)
                    .frame(width: 14, height: 14)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.summary)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(event.timeRangeString)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }

            // Google Meet / Video Join Button
            if let meetLink = event.hangoutLink, !meetLink.isEmpty {
                Button(action: {
                    if let url = URL(string: meetLink) {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "video.fill")
                        Text("Join with Google Meet")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(GooglePalette.googleBlue)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }

            // Location
            if let loc = event.location, !loc.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .frame(width: 16)
                    Text(loc)
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                }
            }

            // Attendees
            if !event.attendees.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "person.2")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .frame(width: 16)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(event.attendees.count) guests")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                        Text(event.attendees.joined(separator: ", "))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
            }

            // Description
            if let desc = event.description, !desc.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .frame(width: 16)
                    ScrollView {
                        Text(cleanHtml(desc))
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 90)
                }
            }

            Divider()

            // Footer
            HStack {
                if let html = event.htmlLink, let url = URL(string: html) {
                    Button(action: {
                        NSWorkspace.shared.open(url)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right.square")
                            Text("Open in Google Calendar")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(GooglePalette.googleBlue)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button("Done", action: onClose)
                    .font(.system(size: 11, weight: .medium))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }

    private func cleanHtml(_ text: String) -> String {
        var str = text.replacingOccurrences(of: "<br>", with: "\n")
        str = str.replacingOccurrences(of: "<br/>", with: "\n")
        str = str.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        return str.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
