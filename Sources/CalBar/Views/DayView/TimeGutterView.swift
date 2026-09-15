import SwiftUI

public struct TimeGutterView: View {
    public let hourHeight: CGFloat
    public let startHour: Int
    public let endHour: Int
    public let topPadding: CGFloat
    public let bottomPadding: CGFloat

    public init(
        hourHeight: CGFloat,
        startHour: Int = 0,
        endHour: Int = 24,
        topPadding: CGFloat = 0,
        bottomPadding: CGFloat = 0
    ) {
        self.hourHeight = hourHeight
        self.startHour = startHour
        self.endHour = endHour
        self.topPadding = topPadding
        self.bottomPadding = bottomPadding
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Headroom before the first hour
            if topPadding > 0 {
                Color.clear
                    .frame(width: 48, height: topPadding)
            }

            ForEach(startHour..<endHour, id: \.self) { hour in
                ZStack(alignment: .topTrailing) {
                    if shouldShowLabel(for: hour) {
                        Text(hourLabel(for: hour))
                            .font(.system(size: 9.5, weight: .regular))
                            .foregroundColor(.secondary)
                            .offset(y: -7)
                            .padding(.trailing, 8)
                    }
                }
                .frame(width: 48, height: hourHeight, alignment: .topTrailing)
            }

            // Closing delimiter label for the concluding hour (e.g. 5 PM)
            if shouldShowLabel(for: endHour) {
                ZStack(alignment: .topTrailing) {
                    Text(hourLabel(for: endHour))
                        .font(.system(size: 9.5, weight: .regular))
                        .foregroundColor(.secondary)
                        .offset(y: -7)
                        .padding(.trailing, 8)
                }
                .frame(width: 48, height: bottomPadding, alignment: .topTrailing)
            } else if bottomPadding > 0 {
                Color.clear
                    .frame(width: 48, height: bottomPadding)
            }
        }
    }

    private func shouldShowLabel(for hour: Int) -> Bool {
        if hour == 0 { return false }
        if hour == 24 { return false }
        return true
    }

    private func hourLabel(for hour: Int) -> String {
        if hour == 0 || hour == 24 { return "" }
        if hour < 12 { return "\(hour) AM" }
        if hour == 12 { return "12 PM" }
        return "\(hour - 12) PM"
    }
}

public struct HourGridLinesView: View {
    public let hourHeight: CGFloat
    public let startHour: Int
    public let endHour: Int
    public let topPadding: CGFloat
    public let bottomPadding: CGFloat

    public init(
        hourHeight: CGFloat,
        startHour: Int = 0,
        endHour: Int = 24,
        topPadding: CGFloat = 0,
        bottomPadding: CGFloat = 0
    ) {
        self.hourHeight = hourHeight
        self.startHour = startHour
        self.endHour = endHour
        self.topPadding = topPadding
        self.bottomPadding = bottomPadding
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Headroom before first hour
            if topPadding > 0 {
                Color.clear
                    .frame(height: topPadding)
            }

            ForEach(startHour..<endHour, id: \.self) { _ in
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 1)
                    Spacer()
                }
                .frame(height: hourHeight)
            }

            // Concluding bottom horizontal grid line at endHour
            if shouldShowClosingLine {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 1)
                    Spacer()
                }
                .frame(height: bottomPadding > 0 ? bottomPadding : 1)
            } else if bottomPadding > 0 {
                Color.clear
                    .frame(height: bottomPadding)
            }
        }
    }

    private var shouldShowClosingLine: Bool {
        // In working hours mode (e.g. 9-17), provide the closing line at 5 PM
        return endHour < 24
    }
}
