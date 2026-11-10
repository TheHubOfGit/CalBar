import SwiftUI

/// Immutable description of the timeline's vertical coordinate system.
///
/// Every view that draws into the timeline (grid lines, events, the now-line, past shading)
/// derives its geometry from this one value instead of recomputing the same arithmetic — and
/// because it is `Equatable`, SwiftUI can skip whole subtrees when nothing about the
/// coordinate system actually changed.
public struct TimelineGeometry: Equatable, Sendable {
    public static let gutterWidth: CGFloat = 48

    public let startHour: Int
    public let endHour: Int
    public let hourHeight: CGFloat
    public let topPadding: CGFloat
    public let bottomPadding: CGFloat

    public init(startHour: Int, endHour: Int, hourHeight: CGFloat, topPadding: CGFloat, bottomPadding: CGFloat) {
        self.startHour = startHour
        self.endHour = endHour
        self.hourHeight = hourHeight
        self.topPadding = topPadding
        self.bottomPadding = bottomPadding
    }

    @MainActor
    public init(coordinator: CalendarSyncCoordinator) {
        self.init(
            startHour: coordinator.timelineStartHour,
            endHour: coordinator.timelineEndHour,
            hourHeight: coordinator.currentHourHeight,
            topPadding: coordinator.timelineTopPadding,
            bottomPadding: coordinator.timelineBottomPadding
        )
    }

    public var startMinute: Double { Double(startHour * 60) }
    public var endMinute: Double { Double(endHour * 60) }
    public var totalHours: Int { max(1, endHour - startHour) }

    public var totalHeight: CGFloat {
        topPadding + CGFloat(totalHours) * hourHeight + bottomPadding
    }

    /// Vertical offset of a given minute-of-day within the canvas.
    public func y(forMinute minute: Double) -> CGFloat {
        topPadding + CGFloat((minute - startMinute) / 60.0) * hourHeight
    }

    public func contains(minute: Double) -> Bool {
        minute >= startMinute && minute <= endMinute
    }

    /// Height of the region between the top of the timeline and `minute`, clamped to the canvas.
    public func elapsedHeight(upTo minute: Double) -> CGFloat {
        let clamped = min(max(minute, startMinute), endMinute)
        return topPadding + CGFloat((clamped - startMinute) / 60.0) * hourHeight
    }
}

/// An event resolved all the way down to a concrete rectangle, computed once per layout pass
/// rather than inside the `ForEach` body on every render.
public struct LaidOutEvent: Identifiable, Equatable {
    public let id: String
    public let event: CalendarEvent
    public let frame: CGRect

    public static func == (lhs: LaidOutEvent, rhs: LaidOutEvent) -> Bool {
        lhs.id == rhs.id && lhs.frame == rhs.frame && lhs.event == rhs.event
    }
}

public struct EventColumnMetrics: Sendable {
    public let leadingInset: CGFloat
    public let trailingInset: CGFloat
    public let gap: CGFloat
    public let minWidth: CGFloat
    public let minHeight: CGFloat

    public static let day = EventColumnMetrics(leadingInset: 3, trailingInset: 5, gap: 2, minWidth: 36, minHeight: 20)
    public static let week = EventColumnMetrics(leadingInset: 2.5, trailingInset: 2.5, gap: 1.5, minWidth: 16, minHeight: 18)
}

extension TimelineGeometry {
    /// Clips to the visible hour window, resolves frames, and drops anything off-screen —
    /// so the `ForEach` that consumes this is a flat list with no conditionals in its body.
    public func layout(
        _ items: [PositionedEvent],
        columnWidth: CGFloat,
        metrics: EventColumnMetrics
    ) -> [LaidOutEvent] {
        guard columnWidth > 0, !items.isEmpty else { return [] }

        let available = max(1, columnWidth - metrics.leadingInset - metrics.trailingInset)
        var result: [LaidOutEvent] = []
        result.reserveCapacity(items.count)

        for item in items {
            let eventStart = item.event.startMinuteOfDay
            let eventEnd = eventStart + item.event.durationMinutes
            guard eventStart < endMinute, eventEnd > startMinute else { continue }

            let top = y(forMinute: max(startMinute, eventStart))
            let bottom = y(forMinute: min(endMinute, eventEnd))

            let frame = CGRect(
                x: CGFloat(item.leftFraction) * available + metrics.leadingInset,
                y: top,
                width: max(metrics.minWidth, CGFloat(item.widthFraction) * available - metrics.gap),
                height: max(metrics.minHeight, bottom - top)
            )
            result.append(LaidOutEvent(id: item.id, event: item.event, frame: frame))
        }

        return result
    }
}
