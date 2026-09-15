import SwiftUI

private struct WeekScrollOffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

public struct WeekGridView: View {
    @ObservedObject var coordinator: CalendarSyncCoordinator

    public init(coordinator: CalendarSyncCoordinator) {
        self.coordinator = coordinator
    }

    private var hourHeight: CGFloat {
        coordinator.currentHourHeight
    }

    private var startHour: Int {
        coordinator.timelineStartHour
    }

    private var endHour: Int {
        coordinator.timelineEndHour
    }

    private var totalHours: Int {
        coordinator.totalTimelineHours
    }

    private var topPadding: CGFloat {
        coordinator.timelineTopPadding
    }

    private var bottomPadding: CGFloat {
        coordinator.timelineBottomPadding
    }

    private var totalCanvasHeight: CGFloat {
        coordinator.totalTimelineCanvasHeight
    }

    private var weekDays: [Date] {
        coordinator.currentWeekDays
    }

    private var allDayEvents: [CalendarEvent] {
        coordinator.events.filter { $0.isAllDay }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Week Day Header (fixed 52pt height)
            WeekDayHeader(
                days: weekDays,
                selectedDate: coordinator.selectedDate
            ) { clickedDate in
                coordinator.selectedDate = clickedDate
                coordinator.viewMode = .day
            }

            // All-Day Row for Week View (if any exist)
            if !allDayEvents.isEmpty {
                HStack(alignment: .center, spacing: 0) {
                    Text("all-day")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 48, alignment: .trailing)
                        .padding(.trailing, 6)

                    HStack(spacing: 0) {
                        ForEach(weekDays, id: \.self) { day in
                            let dayAllDay = allDayEvents.filter { day.isSameDay(as: $0.start) }
                            VStack(spacing: 2) {
                                ForEach(dayAllDay) { ev in
                                    WeekAllDayChip(
                                        event: ev,
                                        isPassed: day < Date().startOfDay(),
                                        blurRadius: coordinator.passedEventBlurRadius
                                    ) {
                                        coordinator.selectedEventForDetail = ev
                                    }
                                }
                            }
                            .padding(.horizontal, 2)
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.02))
                .overlay(Divider(), alignment: .bottom)
            }

            // Scrollable Week Grid
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: !coordinator.limitWorkingHours) {
                    HStack(alignment: .top, spacing: 0) {
                        // Left: Time Gutter
                        TimeGutterView(
                            hourHeight: hourHeight,
                            startHour: startHour,
                            endHour: endHour,
                            topPadding: topPadding,
                            bottomPadding: bottomPadding
                        )
                        .frame(width: 48)

                        // Right: Week day columns
                        GeometryReader { geo in
                            let totalWidth = geo.size.width
                            let columnWidth = totalWidth / CGFloat(max(1, weekDays.count))
                            let startMinutes = Double(startHour * 60)
                            let endMinutes = Double(endHour * 60)
                            let todayStart = Date().startOfDay()

                            ZStack(alignment: .topLeading) {
                                // Background hour lines
                                HourGridLinesView(
                                    hourHeight: hourHeight,
                                    startHour: startHour,
                                    endHour: endHour,
                                    topPadding: topPadding,
                                    bottomPadding: bottomPadding
                                )

                                // 7 Columns
                                HStack(spacing: 0) {
                                    ForEach(Array(weekDays.enumerated()), id: \.offset) { index, day in
                                        let positionedEvents = coordinator.positionedEvents(for: day)
                                        let isToday = day.isToday
                                        let isPastDay = day < todayStart

                                        ZStack(alignment: .topLeading) {
                                            // Vertical column border
                                            Rectangle()
                                                .fill(Color.primary.opacity(0.12))
                                                .frame(width: 1)
                                                .frame(height: totalCanvasHeight)

                                            // Events
                                            ForEach(positionedEvents) { item in
                                                let evStart = item.event.startMinuteOfDay
                                                let evEnd = evStart + item.event.durationMinutes

                                                if evStart < endMinutes && evEnd > startMinutes {
                                                    let availableColWidth = columnWidth - 5
                                                    let clampedStart = max(startMinutes, evStart)
                                                    let clampedEnd = min(endMinutes, evEnd)
                                                    let rawTop = topPadding + ((clampedStart - startMinutes) / 60.0) * hourHeight
                                                    let rawBottom = topPadding + ((clampedEnd - startMinutes) / 60.0) * hourHeight
                                                    let height = max(18, rawBottom - rawTop)
                                                    let leftOffset = item.leftFraction * availableColWidth + 2.5
                                                    let width = max(16, item.widthFraction * availableColWidth - 1.5)

                                                    TimedEventBlock(
                                                        event: item.event,
                                                        isPassed: isPastDay || item.event.isPassed,
                                                        blurRadius: coordinator.passedEventBlurRadius
                                                    ) { selected in
                                                        coordinator.selectedEventForDetail = selected
                                                    }
                                                    .frame(width: width, height: height)
                                                    .offset(x: leftOffset, y: rawTop)
                                                }
                                            }

                                            // Passed Time Shading Overlay for this column
                                            if coordinator.shadePastTime {
                                                if isPastDay {
                                                    // Entire day in the past
                                                    Rectangle()
                                                        .fill(coordinator.pastTimeColor.color.opacity(coordinator.pastTimeOpacity))
                                                        .frame(width: columnWidth, height: totalCanvasHeight)
                                                        .allowsHitTesting(false)
                                                } else if isToday {
                                                    // Today up to the current minute
                                                    let currentMin = Date().minuteOfDay
                                                    if currentMin > startMinutes {
                                                        let elapsedHeight = min(CGFloat(totalHours) * hourHeight, CGFloat((currentMin - startMinutes) / 60.0) * hourHeight)
                                                        let shadeHeight = topPadding + elapsedHeight
                                                        Rectangle()
                                                            .fill(coordinator.pastTimeColor.color.opacity(coordinator.pastTimeOpacity))
                                                            .frame(width: columnWidth, height: shadeHeight)
                                                            .allowsHitTesting(false)
                                                    }
                                                }
                                            }

                                            // Current time indicator line on today's column with dot
                                            if isToday {
                                                let currentMin = Date().minuteOfDay
                                                if currentMin >= startMinutes && currentMin <= endMinutes {
                                                    let yOffset = topPadding + ((currentMin - startMinutes) / 60.0) * hourHeight
                                                    ZStack(alignment: .topLeading) {
                                                        Rectangle()
                                                            .fill(GooglePalette.googleRed)
                                                            .frame(width: columnWidth, height: 1.5)

                                                        Circle()
                                                            .fill(GooglePalette.googleRed)
                                                            .frame(width: 6, height: 6)
                                                            .offset(x: -3, y: -2.25)
                                                    }
                                                    .offset(y: yOffset)
                                                }
                                            }
                                        }
                                        .frame(width: columnWidth, height: totalCanvasHeight)
                                    }
                                }

                                // Scroll Anchors
                                VStack(spacing: 0) {
                                    Color.clear.frame(height: topPadding)
                                    ForEach(startHour..<endHour, id: \.self) { hour in
                                        Color.clear
                                            .frame(height: hourHeight)
                                            .id("week-hour-\(hour)")
                                    }
                                }
                            }
                            .frame(width: totalWidth, height: totalCanvasHeight)
                        }
                    }
                    .frame(height: totalCanvasHeight)
                    .background(
                        GeometryReader { contentGeo in
                            Color.clear.preference(
                                key: WeekScrollOffsetPreferenceKey.self,
                                value: contentGeo.frame(in: .named("weekScrollArea")).minY
                            )
                        }
                    )
                }
                .coordinateSpace(name: "weekScrollArea")
                .onPreferenceChange(WeekScrollOffsetPreferenceKey.self) { minY in
                    let scrolledOffset = -minY - topPadding
                    if scrolledOffset > 0 {
                        let approximateHour = startHour + Int(scrolledOffset / hourHeight)
                        coordinator.lastScrollHour = max(startHour, min(endHour - 1, approximateHour))
                    }
                }
                .onAppear {
                    let targetHour = coordinator.targetScrollHour(isToday: true)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo("week-hour-\(targetHour)", anchor: .top)
                        }
                    }
                }
            }
        }
    }
}

private struct WeekAllDayChip: View {
    let event: CalendarEvent
    let isPassed: Bool
    let blurRadius: CGFloat
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(event.summary)
                .font(.system(size: 9.5, weight: .bold))
                .foregroundColor(event.contrastTextColor)
                .lineLimit(1)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(event.resolvedColor)
                .cornerRadius(3)
                .blur(radius: isPassed ? blurRadius : 0)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .buttonStyle(.plain)
    }
}

