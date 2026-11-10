import SwiftUI

public struct WeekDayHeader: View {
    public let days: [Date]
    public let selectedDate: Date
    public let todayStart: Date
    public let onSelectDay: (Date) -> Void

    public init(days: [Date], selectedDate: Date, todayStart: Date, onSelectDay: @escaping (Date) -> Void) {
        self.days = days
        self.selectedDate = selectedDate
        self.todayStart = todayStart
        self.onSelectDay = onSelectDay
    }

    public var body: some View {
        HStack(spacing: 0) {
            // Matches the time gutter so the columns line up with the grid below.
            Color.clear
                .frame(width: TimelineGeometry.gutterWidth, height: 1)

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
        let isToday = day.isSameDay(as: todayStart)
        let isSelected = day.isSameDay(as: selectedDate)

        DayHeaderButton(
            day: day,
            isToday: isToday,
            isSelected: isSelected,
            action: { onSelectDay(day) }
        )
    }
}

private struct DayHeaderButton: View {
    let day: Date
    let isToday: Bool
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(day.formattedWeekdayShort())
                    .font(.system(size: 9.5, weight: isToday ? .bold : .semibold))
                    .foregroundColor(isToday ? GooglePalette.googleBlue : .secondary)

                ZStack {
                    if isToday {
                        Circle().fill(GooglePalette.googleBlue)
                    } else if isSelected {
                        Circle().stroke(GooglePalette.googleBlue, lineWidth: 1.5)
                    } else if isHovered {
                        Circle().fill(Color.primary.opacity(0.08))
                    }

                    Text(day.formattedDayNumber())
                        .font(.system(size: 12.5, weight: isToday ? .bold : .medium))
                        .monospacedDigit()
                        .foregroundColor(isToday ? .white : (isSelected ? GooglePalette.googleBlue : .primary))
                }
                .frame(width: 24, height: 24)
                .animation(.easeOut(duration: 0.12), value: isHovered)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
