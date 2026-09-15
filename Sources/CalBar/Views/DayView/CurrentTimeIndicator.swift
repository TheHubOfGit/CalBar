import SwiftUI

public struct CurrentTimeIndicator: View {
    public let hourHeight: CGFloat
    public let totalWidth: CGFloat
    public let currentMinute: Double
    public let startHour: Int
    public let endHour: Int
    public let topPadding: CGFloat

    public init(
        hourHeight: CGFloat,
        totalWidth: CGFloat,
        currentMinute: Double = Date().minuteOfDay,
        startHour: Int = 0,
        endHour: Int = 24,
        topPadding: CGFloat = 8.0
    ) {
        self.hourHeight = hourHeight
        self.totalWidth = totalWidth
        self.currentMinute = currentMinute
        self.startHour = startHour
        self.endHour = endHour
        self.topPadding = topPadding
    }

    public var body: some View {
        let startMinutes = Double(startHour * 60)
        let endMinutes = Double(endHour * 60)

        if currentMinute >= startMinutes && currentMinute <= endMinutes {
            let yOffset = topPadding + ((currentMinute - startMinutes) / 60.0) * hourHeight

            ZStack(alignment: .topLeading) {
                // Red horizontal hairline spanning full width
                Rectangle()
                    .fill(GooglePalette.googleRed)
                    .frame(width: totalWidth, height: 1.5)

                // Red dot centered on the left border of the column
                Circle()
                    .fill(GooglePalette.googleRed)
                    .frame(width: 8, height: 8)
                    .offset(x: -4, y: -3.25)
            }
            .offset(y: yOffset)
        }
    }
}

