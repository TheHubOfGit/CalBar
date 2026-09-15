import SwiftUI

private struct DayScrollOffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

public struct DayGridView: View {
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

    private var dayEvents: [CalendarEvent] {
        coordinator.events.filter { event in
            coordinator.selectedDate.isSameDay(as: event.start)
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // All-Day Events Shelf
            AllDayEventsShelf(
                events: dayEvents,
                blurRadius: coordinator.passedEventBlurRadius
            ) { selected in
                coordinator.selectedEventForDetail = selected
            }

            // Scrollable Timeline
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

                        // Right: Events Canvas
                        GeometryReader { geo in
                            let canvasWidth = geo.size.width
                            let startMinutes = Double(startHour * 60)
                            let endMinutes = Double(endHour * 60)
                            let positionedEvents = coordinator.positionedEvents(for: coordinator.selectedDate)

                            ZStack(alignment: .topLeading) {
                                // Background Hour Divider Lines
                                HourGridLinesView(
                                    hourHeight: hourHeight,
                                    startHour: startHour,
                                    endHour: endHour,
                                    topPadding: topPadding,
                                    bottomPadding: bottomPadding
                                )

                                // Vertical Divider between Gutter and Canvas
                                Rectangle()
                                    .fill(Color.primary.opacity(0.12))
                                    .frame(width: 1)
                                    .frame(height: totalCanvasHeight)

                                // Positioned Timed Events
                                ForEach(positionedEvents) { item in
                                    let evStart = item.event.startMinuteOfDay
                                    let evEnd = evStart + item.event.durationMinutes

                                    if evStart < endMinutes && evEnd > startMinutes {
                                        let availableWidth = canvasWidth - 8
                                        let leftOffset = item.leftFraction * availableWidth + 3
                                        let width = max(36, item.widthFraction * availableWidth - 2)

                                        let clampedStart = max(startMinutes, evStart)
                                        let clampedEnd = min(endMinutes, evEnd)
                                        let rawTop = topPadding + ((clampedStart - startMinutes) / 60.0) * hourHeight
                                        let rawBottom = topPadding + ((clampedEnd - startMinutes) / 60.0) * hourHeight
                                        let height = max(20, rawBottom - rawTop)

                                        TimedEventBlock(
                                            event: item.event,
                                            isPassed: coordinator.selectedDate < Date().startOfDay() || item.event.isPassed,
                                            blurRadius: coordinator.passedEventBlurRadius
                                        ) { selected in
                                            coordinator.selectedEventForDetail = selected
                                        }
                                        .frame(width: width, height: height)
                                        .offset(x: leftOffset, y: rawTop)
                                    }
                                }

                                // Passed Time Shading Overlay
                                if coordinator.shadePastTime {
                                    if coordinator.selectedDate.isToday {
                                        let currentMin = Date().minuteOfDay
                                        if currentMin > startMinutes {
                                            let elapsedHeight = min(CGFloat(totalHours) * hourHeight, CGFloat((currentMin - startMinutes) / 60.0) * hourHeight)
                                            let shadeHeight = topPadding + elapsedHeight
                                            Rectangle()
                                                .fill(coordinator.pastTimeColor.color.opacity(coordinator.pastTimeOpacity))
                                                .frame(width: canvasWidth, height: shadeHeight)
                                                .allowsHitTesting(false)
                                        }
                                    } else if coordinator.selectedDate < Date().startOfDay() {
                                        Rectangle()
                                            .fill(coordinator.pastTimeColor.color.opacity(coordinator.pastTimeOpacity))
                                            .frame(width: canvasWidth, height: totalCanvasHeight)
                                            .allowsHitTesting(false)
                                    }
                                }

                                // Live Current Time Indicator (rendered on top of shading)
                                if coordinator.selectedDate.isToday {
                                    CurrentTimeIndicator(
                                        hourHeight: hourHeight,
                                        totalWidth: canvasWidth,
                                        startHour: startHour,
                                        endHour: endHour,
                                        topPadding: topPadding
                                    )
                                }

                                // Scroll Anchors
                                VStack(spacing: 0) {
                                    Color.clear.frame(height: topPadding)
                                    ForEach(startHour..<endHour, id: \.self) { hour in
                                        Color.clear
                                            .frame(height: hourHeight)
                                            .id("day-hour-\(hour)")
                                    }
                                }
                            }
                            .frame(width: canvasWidth, height: totalCanvasHeight)
                        }
                    }
                    .frame(height: totalCanvasHeight)
                    .background(
                        GeometryReader { contentGeo in
                            Color.clear.preference(
                                key: DayScrollOffsetPreferenceKey.self,
                                value: contentGeo.frame(in: .named("dayScrollArea")).minY
                            )
                        }
                    )
                }
                .coordinateSpace(name: "dayScrollArea")
                .onPreferenceChange(DayScrollOffsetPreferenceKey.self) { minY in
                    let scrolledOffset = -minY - topPadding
                    if scrolledOffset > 0 {
                        let approximateHour = startHour + Int(scrolledOffset / hourHeight)
                        coordinator.lastScrollHour = max(startHour, min(endHour - 1, approximateHour))
                    }
                }
                .onAppear {
                    let targetHour = coordinator.targetScrollHour(isToday: coordinator.selectedDate.isToday)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo("day-hour-\(targetHour)", anchor: .top)
                        }
                    }
                }
            }
        }
    }
}
