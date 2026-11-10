import SwiftUI

public struct TimeGutterView: View {
    public let geometry: TimelineGeometry
    /// Hour to render in the "now" accent, or `nil` when the column isn't today.
    public let highlightedHour: Int?

    public init(geometry: TimelineGeometry, highlightedHour: Int? = nil) {
        self.geometry = geometry
        self.highlightedHour = highlightedHour
    }

    public var body: some View {
        VStack(spacing: 0) {
            if geometry.topPadding > 0 {
                Color.clear.frame(height: geometry.topPadding)
            }

            ForEach(geometry.startHour..<geometry.endHour, id: \.self) { hour in
                label(for: hour)
                    .frame(width: TimelineGeometry.gutterWidth, height: geometry.hourHeight, alignment: .topTrailing)
            }

            // Closing label for a bounded window (e.g. 5 PM in working-hours mode).
            if hasLabel(geometry.endHour) {
                label(for: geometry.endHour)
                    .frame(width: TimelineGeometry.gutterWidth, height: geometry.bottomPadding, alignment: .topTrailing)
            } else if geometry.bottomPadding > 0 {
                Color.clear.frame(height: geometry.bottomPadding)
            }
        }
        .frame(width: TimelineGeometry.gutterWidth)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func label(for hour: Int) -> some View {
        if hasLabel(hour) {
            let isNow = hour == highlightedHour
            Text(Self.hourLabel(hour))
                .font(.system(size: 9.5, weight: isNow ? .semibold : .regular))
                .monospacedDigit()
                .foregroundColor(isNow ? GooglePalette.googleRed : .secondary)
                .fixedSize()
                .offset(y: -7)
                .padding(.trailing, 8)
        } else {
            Color.clear
        }
    }

    private func hasLabel(_ hour: Int) -> Bool {
        hour != 0 && hour != 24
    }

    private static func hourLabel(_ hour: Int) -> String {
        if hour == 0 || hour == 24 { return "" }
        if hour < 12 { return "\(hour) AM" }
        if hour == 12 { return "12 PM" }
        return "\(hour - 12) PM"
    }
}
