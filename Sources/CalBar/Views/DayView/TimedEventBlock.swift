import SwiftUI

public struct TimedEventBlock: View {
    public let event: CalendarEvent
    public let isPassed: Bool
    public let blurRadius: CGFloat
    public let onSelect: (CalendarEvent) -> Void
    @State private var isHovered: Bool = false

    public init(
        event: CalendarEvent,
        isPassed: Bool? = nil,
        blurRadius: CGFloat = 0,
        onSelect: @escaping (CalendarEvent) -> Void
    ) {
        self.event = event
        self.isPassed = isPassed ?? event.isPassed
        self.blurRadius = blurRadius
        self.onSelect = onSelect
    }

    public var body: some View {
        Button(action: {
            onSelect(event)
        }) {
            ZStack(alignment: .topLeading) {
                // Vibrant Google Calendar Solid Fill
                RoundedRectangle(cornerRadius: 4)
                    .fill(event.resolvedColor)

                // High-contrast subtle border
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isHovered ? Color.white.opacity(0.8) : Color.white.opacity(0.15), lineWidth: isHovered ? 1.5 : 0.8)

                // Event Content
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(event.summary)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(event.contrastTextColor)
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        if let meet = event.hangoutLink, !meet.isEmpty {
                            Button(action: {
                                if let url = URL(string: meet) {
                                    NSWorkspace.shared.open(url)
                                }
                            }) {
                                HStack(spacing: 2.5) {
                                    Image(systemName: "video.fill")
                                        .font(.system(size: 7.5))
                                    Text("Join")
                                        .font(.system(size: 8.5, weight: .bold))
                                }
                                .padding(.horizontal, 4.5)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.25))
                                .foregroundColor(event.contrastTextColor)
                                .cornerRadius(3)
                            }
                            .buttonStyle(.plain)
                            .help("Join Video Meeting")
                        }
                    }

                    if event.durationMinutes >= 25 {
                        Text(event.timeRangeString)
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundColor(event.contrastTextColor.opacity(0.85))
                            .lineLimit(1)
                    }

                    if let loc = event.location, !loc.isEmpty, event.durationMinutes >= 45 {
                        HStack(spacing: 2) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 8))
                            Text(loc)
                                .font(.system(size: 9))
                                .lineLimit(1)
                        }
                        .foregroundColor(event.contrastTextColor.opacity(0.8))
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3.5)
            }
            .blur(radius: (isPassed && !isHovered) ? blurRadius : 0)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .animation(.easeInOut(duration: 0.18), value: isHovered)
            .shadow(color: Color.black.opacity(isHovered ? 0.25 : 0.08), radius: isHovered ? 3 : 1, y: 1)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
