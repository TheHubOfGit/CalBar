import SwiftUI

private struct DayScrollOffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

public struct DayGridView: View {
    @ObservedObject var coordinator: CalendarSyncCoordinator
    /// The day this page renders. Fixed per page so the pager can show neighbouring days
    /// side by side while the user is mid-swipe.
    let date: Date

    private static let anchorPrefix = "day"

    public init(coordinator: CalendarSyncCoordinator, date: Date) {
        self.coordinator = coordinator
        self.date = date
    }

    private var geometry: TimelineGeometry {
        TimelineGeometry(coordinator: coordinator)
    }

    private var isToday: Bool {
        date.isSameDay(as: coordinator.todayStart)
    }

    private var isPastDay: Bool {
        date.startOfDay() < coordinator.todayStart
    }

    public var body: some View {
        let geo = geometry

        VStack(spacing: 0) {
            AllDayEventsShelf(
                events: coordinator.allDayEvents(for: date),
                blurRadius: coordinator.passedEventBlurRadius
            ) { selected in
                coordinator.present(selected)
            }

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: !coordinator.limitWorkingHours) {
                    HStack(alignment: .top, spacing: 0) {
                        TimeGutterView(
                            geometry: geo,
                            highlightedHour: isToday ? Int(coordinator.currentMinute / 60.0) : nil
                        )

                        GeometryReader { canvasGeo in
                            canvas(width: canvasGeo.size.width, geo: geo)
                        }
                    }
                    .frame(height: geo.totalHeight)
                    .background(scrollOffsetReporter)
                }
                .coordinateSpace(name: "dayScrollArea")
                .onPreferenceChange(DayScrollOffsetPreferenceKey.self) { minY in
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
        coordinator.targetScrollHour(isToday: isToday)
    }

    @ViewBuilder
    private func canvas(width: CGFloat, geo: TimelineGeometry) -> some View {
        let events = geo.layout(
            coordinator.positionedEvents(for: date),
            columnWidth: width,
            metrics: .day
        )

        ZStack(alignment: .topLeading) {
            HourGridLinesView(geometry: geo)

            // Divider between the gutter and the canvas.
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

            if coordinator.shadePastTime, let extent = shadeExtent {
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

            TimelineScrollAnchors(geometry: geo, prefix: Self.anchorPrefix)
        }
        .frame(width: width, height: geo.totalHeight)
    }

    private var shadeExtent: PastTimeShade.Extent? {
        if isToday { return .upTo(minute: coordinator.currentMinute) }
        if isPastDay { return .fullDay }
        return nil
    }

    /// Only installed for the "restore last position" behavior — the geometry reader and
    /// preference plumbing it needs would otherwise run on every scrolled frame for nothing.
    @ViewBuilder
    private var scrollOffsetReporter: some View {
        if coordinator.scrollBehavior == .retainPosition {
            GeometryReader { contentGeo in
                Color.clear.preference(
                    key: DayScrollOffsetPreferenceKey.self,
                    value: contentGeo.frame(in: .named("dayScrollArea")).minY
                )
            }
        }
    }

    private func recordScrollPosition(minY: CGFloat, geo: TimelineGeometry) {
        guard coordinator.scrollBehavior == .retainPosition,
              date.isSameDay(as: coordinator.selectedDate) else { return }
        let scrolled = -minY - geo.topPadding
        guard scrolled > 0 else { return }
        let hour = geo.startHour + Int(scrolled / geo.hourHeight)
        coordinator.lastScrollHour = max(geo.startHour, min(geo.endHour - 1, hour))
    }
}
