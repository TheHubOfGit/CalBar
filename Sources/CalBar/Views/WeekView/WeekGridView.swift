import SwiftUI

private struct WeekScrollOffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

public struct WeekGridView: View {
    @ObservedObject var coordinator: CalendarSyncCoordinator

    private static let anchorPrefix = "week"

    public init(coordinator: CalendarSyncCoordinator) {
        self.coordinator = coordinator
    }

    private var geometry: TimelineGeometry {
        TimelineGeometry(coordinator: coordinator)
    }

    private var weekDays: [Date] {
        coordinator.currentWeekDays
    }

    public var body: some View {
        let geo = geometry
        let days = weekDays

        VStack(spacing: 0) {
            WeekDayHeader(
                days: days,
                selectedDate: coordinator.selectedDate,
                todayStart: coordinator.todayStart
            ) { clickedDate in
                coordinator.selectedDate = clickedDate
                coordinator.viewMode = .day
                coordinator.requestScrollToTarget()
            }

            allDayRow(days: days)

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: !coordinator.limitWorkingHours) {
                    HStack(alignment: .top, spacing: 0) {
                        TimeGutterView(
                            geometry: geo,
                            highlightedHour: coordinator.weekContainsToday ? Int(coordinator.currentMinute / 60.0) : nil
                        )

                        GeometryReader { canvasGeo in
                            canvas(width: canvasGeo.size.width, days: days, geo: geo)
                        }
                    }
                    .frame(height: geo.totalHeight)
                    .background(scrollOffsetReporter)
                }
                .coordinateSpace(name: "weekScrollArea")
                .onPreferenceChange(WeekScrollOffsetPreferenceKey.self) { minY in
                    Task { @MainActor in
                        recordScrollPosition(minY: minY, geo: geo)
                    }
                }
                .onAppear {
                    TimelineScroller.scrollSettling(proxy, prefix: Self.anchorPrefix, hour: targetHour)
                }
                .onChange(of: coordinator.scrollRequestToken) { _, _ in
                    TimelineScroller.scroll(proxy, prefix: Self.anchorPrefix, hour: targetHour)
                }
                .onChange(of: geo) { _, _ in
                    TimelineScroller.scrollSettling(proxy, prefix: Self.anchorPrefix, hour: targetHour)
                }
            }
        }
    }

    private var targetHour: Int {
        coordinator.targetScrollHour(isToday: coordinator.weekContainsToday)
    }

    // MARK: - All-day row

    @ViewBuilder
    private func allDayRow(days: [Date]) -> some View {
        let perDay = days.map { coordinator.allDayEvents(for: $0) }

        if perDay.contains(where: { !$0.isEmpty }) {
            HStack(alignment: .top, spacing: 0) {
                Text("all-day")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: TimelineGeometry.gutterWidth, alignment: .trailing)
                    .padding(.trailing, 6)

                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(zip(days, perDay)), id: \.0) { day, events in
                        VStack(spacing: 2) {
                            ForEach(events) { event in
                                WeekAllDayChip(
                                    event: event,
                                    isPassed: day < coordinator.todayStart,
                                    blurRadius: coordinator.passedEventBlurRadius
                                ) {
                                    coordinator.present(event)
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                        .frame(maxWidth: .infinity, alignment: .top)
                    }
                }
            }
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.02))
            .overlay(Divider(), alignment: .bottom)
        }
    }

    // MARK: - Timeline canvas

    @ViewBuilder
    private func canvas(width: CGFloat, days: [Date], geo: TimelineGeometry) -> some View {
        let columnWidth = width / CGFloat(max(1, days.count))

        ZStack(alignment: .topLeading) {
            HourGridLinesView(geometry: geo)

            HStack(spacing: 0) {
                ForEach(days, id: \.self) { day in
                    column(day: day, width: columnWidth, geo: geo)
                        .frame(width: columnWidth, height: geo.totalHeight)
                }
            }

            TimelineScrollAnchors(geometry: geo, prefix: Self.anchorPrefix)
        }
        .frame(width: width, height: geo.totalHeight)
    }

    @ViewBuilder
    private func column(day: Date, width: CGFloat, geo: TimelineGeometry) -> some View {
        let isToday = day.isSameDay(as: coordinator.todayStart)
        let isPastDay = day < coordinator.todayStart
        let events = geo.layout(
            coordinator.positionedEvents(for: day),
            columnWidth: width,
            metrics: .week
        )

        ZStack(alignment: .topLeading) {
            if isToday {
                Rectangle()
                    .fill(GooglePalette.googleBlue.opacity(0.045))
                    .frame(width: width, height: geo.totalHeight)
                    .allowsHitTesting(false)
            }

            Rectangle()
                .fill(Color.primary.opacity(0.12))
                .frame(width: 1, height: geo.totalHeight)

            ForEach(events) { item in
                TimedEventBlock(
                    event: item.event,
                    isPassed: isPastDay || item.event.isPassed,
                    blurRadius: coordinator.passedEventBlurRadius,
                    size: item.frame.size
                ) { selected in
                    coordinator.present(selected)
                }
                .frame(width: item.frame.width, height: item.frame.height)
                .offset(x: item.frame.minX, y: item.frame.minY)
            }

            if coordinator.shadePastTime, let extent = shadeExtent(isToday: isToday, isPastDay: isPastDay) {
                PastTimeShade(
                    geometry: geo,
                    width: width,
                    extent: extent,
                    color: coordinator.pastTimeColor.color,
                    opacity: coordinator.pastTimeOpacity
                )
            }

            if isToday {
                CurrentTimeIndicator(
                    geometry: geo,
                    totalWidth: width,
                    currentMinute: coordinator.currentMinute
                )
            }
        }
    }

    private func shadeExtent(isToday: Bool, isPastDay: Bool) -> PastTimeShade.Extent? {
        if isPastDay { return .fullDay }
        if isToday { return .upTo(minute: coordinator.currentMinute) }
        return nil
    }

    @ViewBuilder
    private var scrollOffsetReporter: some View {
        if coordinator.scrollBehavior == .retainPosition {
            GeometryReader { contentGeo in
                Color.clear.preference(
                    key: WeekScrollOffsetPreferenceKey.self,
                    value: contentGeo.frame(in: .named("weekScrollArea")).minY
                )
            }
        }
    }

    private func recordScrollPosition(minY: CGFloat, geo: TimelineGeometry) {
        guard coordinator.scrollBehavior == .retainPosition else { return }
        let scrolled = -minY - geo.topPadding
        guard scrolled > 0 else { return }
        let hour = geo.startHour + Int(scrolled / geo.hourHeight)
        coordinator.lastScrollHour = max(geo.startHour, min(geo.endHour - 1, hour))
    }
}

private struct WeekAllDayChip: View {
    let event: CalendarEvent
    let isPassed: Bool
    let blurRadius: CGFloat
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            Text(event.summary)
                .font(.system(size: 9.5, weight: .bold))
                .foregroundColor(event.contrastTextColor)
                .lineLimit(1)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(event.resolvedColor, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                .pastEventTreatment(isPassed: isPassed && !isHovered, blurRadius: blurRadius)
                .contentShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(event.summary)
    }
}
