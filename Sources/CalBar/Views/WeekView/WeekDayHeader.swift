import SwiftUI

public struct WeekDayHeader: View {
    public let days: [Date]
    public let selectedDate: Date
    public let onSelectDay: (Date) -> Void

    public init(days: [Date], selectedDate: Date, onSelectDay: @escaping (Date) -> Void) {
        self.days = days
        self.selectedDate = selectedDate
        self.onSelectDay = onSelectDay
    }

    public var body: some View {
        HStack(spacing: 0) {
            // Spacer exactly matching the 48pt time gutter width, constrained in height
            Color.clear
                .frame(width: 48, height: 1)

            // 7 Day Headers
            HStack(spacing: 0) {
                ForEach(days, id: \.self) { day in
                    dayCell(day)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: 52)
        .background(Material.bar)
        .overlay(Divider(), alignment: .bottom)
    }

    @ViewBuilder
    private func dayCell(_ day: Date) -> some View {
        let isToday = day.isToday
        let isCurrentSelected = day.isSameDay(as: selectedDate)

        Button(action: {
            onSelectDay(day)
        }) {
            VStack(spacing: 2) {
                Text(day.formattedWeekdayShort())
                    .font(.system(size: 9.5, weight: isToday ? .bold : .semibold))
                    .foregroundColor(isToday ? GooglePalette.googleBlue : .secondary)

                ZStack {
                    if isToday {
                        Circle()
                            .fill(GooglePalette.googleBlue)
                    } else if isCurrentSelected {
                        Circle()
                            .stroke(GooglePalette.googleBlue, lineWidth: 1.5)
                    }

                    Text(day.formattedDayNumber())
                        .font(.system(size: 12.5, weight: isToday ? .bold : .medium))
                        .foregroundColor(isToday ? .white : (isCurrentSelected ? GooglePalette.googleBlue : .primary))
                }
                .frame(width: 24, height: 24)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
