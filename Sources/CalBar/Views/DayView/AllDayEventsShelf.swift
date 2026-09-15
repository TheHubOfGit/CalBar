import SwiftUI

public struct AllDayEventsShelf: View {
    public let events: [CalendarEvent]
    public let blurRadius: CGFloat
    public let onSelect: (CalendarEvent) -> Void

    public init(
        events: [CalendarEvent],
        blurRadius: CGFloat = 0,
        onSelect: @escaping (CalendarEvent) -> Void
    ) {
        self.events = events.filter { $0.isAllDay }
        self.blurRadius = blurRadius
        self.onSelect = onSelect
    }

    public var body: some View {
        if !events.isEmpty {
            HStack(alignment: .top, spacing: 0) {
                // Time gutter alignment label
                Text("all-day")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 48, alignment: .trailing)
                    .padding(.top, 4)

                // Events list
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(events) { event in
                        AllDayEventButton(
                            event: event,
                            blurRadius: blurRadius,
                            onSelect: onSelect
                        )
                    }
                }
                .padding(.leading, 8)
                .padding(.trailing, 12)
            }
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.03))
            .overlay(
                Divider(), alignment: .bottom
            )
        }
    }
}

private struct AllDayEventButton: View {
    let event: CalendarEvent
    let blurRadius: CGFloat
    let onSelect: (CalendarEvent) -> Void
    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: { onSelect(event) }) {
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 3, height: 10)

                Text(event.summary)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundColor(event.contrastTextColor)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(event.resolvedColor)
            .cornerRadius(4)
            .blur(radius: (event.isPassed && !isHovered) ? blurRadius : 0)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .animation(.easeInOut(duration: 0.18), value: isHovered)
            .shadow(color: Color.black.opacity(isHovered ? 0.2 : 0.1), radius: isHovered ? 2 : 1, y: 0.5)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
