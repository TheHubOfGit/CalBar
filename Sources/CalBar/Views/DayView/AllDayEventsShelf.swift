import SwiftUI

public struct AllDayEventsShelf: View {
    public let events: [CalendarEvent]
    public let blurRadius: CGFloat
    public let onSelect: (CalendarEvent) -> Void

    /// Keeps a long list of all-day events from eating the timeline.
    private static let maxVisibleHeight: CGFloat = 76
    private static let maxUnscrolledRows = 3

    public init(
        events: [CalendarEvent],
        blurRadius: CGFloat = 0,
        onSelect: @escaping (CalendarEvent) -> Void
    ) {
        self.events = events
        self.blurRadius = blurRadius
        self.onSelect = onSelect
    }

    public var body: some View {
        if !events.isEmpty {
            HStack(alignment: .top, spacing: 0) {
                Text("all-day")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: TimelineGeometry.gutterWidth, alignment: .trailing)
                    .padding(.top, 4)

                Group {
                    if events.count > Self.maxUnscrolledRows {
                        // A ScrollView is greedy, so it only gets a fixed height once there is
                        // actually something to scroll — otherwise the shelf would reserve the
                        // full height for a single chip.
                        ScrollView(.vertical, showsIndicators: true) {
                            chips
                        }
                        .frame(height: Self.maxVisibleHeight)
                    } else {
                        chips
                    }
                }
                .padding(.leading, 8)
                .padding(.trailing, 12)
            }
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.03))
            .overlay(Divider(), alignment: .bottom)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var chips: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(events) { event in
                AllDayEventButton(
                    event: event,
                    blurRadius: blurRadius,
                    onSelect: onSelect
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AllDayEventButton: View {
    let event: CalendarEvent
    let blurRadius: CGFloat
    let onSelect: (CalendarEvent) -> Void

    @State private var isHovered: Bool = false

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
    }

    var body: some View {
        Button(action: { onSelect(event) }) {
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
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
            .background(event.resolvedColor, in: shape)
            .pastEventTreatment(isPassed: event.isPassed && !isHovered, blurRadius: blurRadius)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .compositingGroup()
        .shadow(color: .black.opacity(isHovered ? 0.18 : 0.08), radius: isHovered ? 2 : 1, y: 0.5)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.14), value: isHovered)
        .help(event.summary)
    }
}
