import SwiftUI

public struct TimedEventBlock: View {
    public let event: CalendarEvent
    public let isPassed: Bool
    public let blurRadius: CGFloat
    /// The block's resolved size. Detail is revealed progressively against real pixels rather
    /// than against duration, so a 30-minute event stays readable at Compact density.
    public let size: CGSize
    public let onSelect: (CalendarEvent) -> Void

    @State private var isHovered: Bool = false

    public init(
        event: CalendarEvent,
        isPassed: Bool? = nil,
        blurRadius: CGFloat = 0,
        size: CGSize,
        onSelect: @escaping (CalendarEvent) -> Void
    ) {
        self.event = event
        self.isPassed = isPassed ?? event.isPassed
        self.blurRadius = blurRadius
        self.size = size
        self.onSelect = onSelect
    }

    private var showsTimeRange: Bool { size.height >= 30 }
    private var showsLocation: Bool { size.height >= 48 && size.width >= 110 }
    private var showsJoinButton: Bool { size.height >= 26 && size.width >= 120 }
    private var isTight: Bool { size.height < 26 }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
    }

    public var body: some View {
        Button(action: { onSelect(event) }) {
            VStack(alignment: .leading, spacing: 1.5) {
                HStack(spacing: 4) {
                    Text(event.summary)
                        .font(.system(size: isTight ? 9.5 : 11, weight: .bold))
                        .foregroundColor(event.contrastTextColor)
                        .lineLimit(1)

                    if isTight, showsTimeRange == false, size.width >= 140 {
                        Text(event.start.formattedTime())
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(event.contrastTextColor.opacity(0.85))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    if showsJoinButton, let meet = event.hangoutLink, !meet.isEmpty {
                        joinButton(link: meet)
                    }
                }

                if showsTimeRange {
                    Text(event.timeRangeString)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(event.contrastTextColor.opacity(0.85))
                        .lineLimit(1)
                }

                if showsLocation, let loc = event.location, !loc.isEmpty {
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
            .padding(.vertical, isTight ? 1 : 3.5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(event.resolvedColor, in: shape)
            .overlay(
                shape.strokeBorder(
                    Color.white.opacity(isHovered ? 0.75 : 0.15),
                    lineWidth: isHovered ? 1.5 : 0.8
                )
            )
            .pastEventTreatment(isPassed: isPassed && !isHovered, blurRadius: blurRadius)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .compositingGroup()
        .shadow(color: .black.opacity(isHovered ? 0.22 : 0.07), radius: isHovered ? 3 : 1, y: 1)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.14), value: isHovered)
        .help(tooltip)
    }

    @ViewBuilder
    private func joinButton(link: String) -> some View {
        Button {
            if let url = URL(string: link) {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack(spacing: 2.5) {
                Image(systemName: "video.fill")
                    .font(.system(size: 7.5))
                Text("Join")
                    .font(.system(size: 8.5, weight: .bold))
            }
            .padding(.horizontal, 4.5)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.28), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
            .foregroundColor(event.contrastTextColor)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Join Video Meeting")
    }

    private var tooltip: String {
        var parts = [event.summary, event.timeRangeString]
        if let loc = event.location, !loc.isEmpty {
            parts.append(loc)
        }
        return parts.joined(separator: "\n")
    }
}
