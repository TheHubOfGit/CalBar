import Testing
import Foundation
import CoreGraphics
@testable import CalBar

private let hourHeight: CGFloat = 52
private let topPadding: CGFloat = 8
private let bottomPadding: CGFloat = 16

private func fullDayGeometry() -> TimelineGeometry {
    TimelineGeometry(
        startHour: 0,
        endHour: 24,
        hourHeight: hourHeight,
        topPadding: topPadding,
        bottomPadding: bottomPadding
    )
}

private func workingHoursGeometry() -> TimelineGeometry {
    TimelineGeometry(
        startHour: 9,
        endHour: 17,
        hourHeight: hourHeight,
        topPadding: topPadding,
        bottomPadding: bottomPadding
    )
}

private func event(
    id: String = "e",
    startHour: Int,
    startMinute: Int = 0,
    durationMinutes: Int,
    isAllDay: Bool = false
) -> CalendarEvent {
    let base = Calendar.current.startOfDay(for: Date())
    let start = Calendar.current.date(bySettingHour: startHour, minute: startMinute, second: 0, of: base)!
    return CalendarEvent(
        id: id,
        calendarId: "cal",
        summary: id,
        start: start,
        end: start.addingTimeInterval(TimeInterval(durationMinutes * 60)),
        isAllDay: isAllDay
    )
}

@Test func totalHeightCoversEveryHourPlusPadding() {
    #expect(fullDayGeometry().totalHeight == topPadding + 24 * hourHeight + bottomPadding)
    #expect(workingHoursGeometry().totalHeight == topPadding + 8 * hourHeight + bottomPadding)
}

@Test func minuteOffsetsAreRelativeToTheWindowStart() {
    let full = fullDayGeometry()
    #expect(full.y(forMinute: 0) == topPadding)
    #expect(full.y(forMinute: 60) == topPadding + hourHeight)

    // In working-hours mode 9 AM sits at the very top of the canvas, not 540pt down.
    let working = workingHoursGeometry()
    #expect(working.y(forMinute: 9 * 60) == topPadding)
    #expect(working.y(forMinute: 10 * 60) == topPadding + hourHeight)
}

@Test func elapsedHeightClampsToTheVisibleWindow() {
    let working = workingHoursGeometry()
    // Before the window opens.
    #expect(working.elapsedHeight(upTo: 6 * 60) == topPadding)
    // After it closes: shading must stop at the last rendered hour.
    #expect(working.elapsedHeight(upTo: 23 * 60) == topPadding + 8 * hourHeight)
}

@Test func layoutPlacesASingleEventAcrossTheFullColumn() {
    let positioned = EventLayoutAlgorithm.layoutEvents([event(startHour: 10, durationMinutes: 60)])
    let laid = fullDayGeometry().layout(positioned, columnWidth: 200, metrics: .day)

    #expect(laid.count == 1)
    let frame = laid[0].frame
    #expect(frame.minY == topPadding + 10 * hourHeight)
    #expect(frame.height == hourHeight)
    #expect(frame.minX == EventColumnMetrics.day.leadingInset)
}

@Test func layoutSplitsOverlappingEventsIntoColumns() {
    let positioned = EventLayoutAlgorithm.layoutEvents([
        event(id: "a", startHour: 10, durationMinutes: 60),
        event(id: "b", startHour: 10, startMinute: 30, durationMinutes: 60)
    ])
    let laid = fullDayGeometry().layout(positioned, columnWidth: 200, metrics: .day)
        .sorted { $0.frame.minX < $1.frame.minX }

    #expect(laid.count == 2)
    #expect(laid[0].frame.minX < laid[1].frame.minX)
    // Neither block may run into the other.
    #expect(laid[0].frame.maxX <= laid[1].frame.minX + EventColumnMetrics.day.gap)
}

@Test func layoutDropsEventsOutsideTheVisibleWindow() {
    let positioned = EventLayoutAlgorithm.layoutEvents([
        event(id: "earlyBird", startHour: 6, durationMinutes: 60),
        event(id: "midday", startHour: 12, durationMinutes: 60)
    ])
    let laid = workingHoursGeometry().layout(positioned, columnWidth: 200, metrics: .day)

    #expect(laid.map(\.id) == ["midday"])
}

@Test func layoutClipsEventsStraddlingTheWindowEdge() {
    // 8:00–10:00 against a 9–17 window: only the 9–10 portion is drawn.
    let positioned = EventLayoutAlgorithm.layoutEvents([event(startHour: 8, durationMinutes: 120)])
    let laid = workingHoursGeometry().layout(positioned, columnWidth: 200, metrics: .day)

    #expect(laid.count == 1)
    #expect(laid[0].frame.minY == topPadding)
    #expect(laid[0].frame.height == hourHeight)
}

@Test func layoutEnforcesAMinimumReadableHeight() {
    let positioned = EventLayoutAlgorithm.layoutEvents([event(startHour: 10, durationMinutes: 5)])
    let laid = fullDayGeometry().layout(positioned, columnWidth: 200, metrics: .day)

    #expect(laid[0].frame.height >= EventColumnMetrics.day.minHeight)
}

@Test func layoutIgnoresZeroWidthColumns() {
    let positioned = EventLayoutAlgorithm.layoutEvents([event(startHour: 10, durationMinutes: 60)])
    #expect(fullDayGeometry().layout(positioned, columnWidth: 0, metrics: .week).isEmpty)
}
