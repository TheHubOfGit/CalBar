import SwiftUI
import AppKit

/// Shows the selected day with its neighbours on either side and lets the user drag between
/// them with a two-finger trackpad swipe. The strip tracks the fingers 1:1, holds wherever
/// they stop, and on release settles on the nearest day (or the next one, if flicked).
struct DayPagerView: View {
    @ObservedObject var coordinator: CalendarSyncCoordinator

    /// Horizontal displacement of the strip from its resting position, in points.
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let width = max(1, geo.size.width)
            let selected = coordinator.selectedDate.startOfDay()
            let days = (-1...1).map { selected.addingDays($0) }

            HStack(spacing: 0) {
                // Keyed by day so a page keeps its identity (and vertical scroll position)
                // when it slides from "next" to "current".
                ForEach(days, id: \.timeIntervalSinceReferenceDate) { day in
                    DayGridView(coordinator: coordinator, date: day)
                        .frame(width: width)
                }
            }
            .frame(width: width * 3, alignment: .leading)
            .offset(x: -width + dragOffset)
            .frame(width: width, alignment: .leading)
            .clipped()
            .background(
                HorizontalSwipeMonitor(
                    isEnabled: coordinator.selectedEventForDetail == nil,
                    onChange: { delta in
                        setOffset(dragOffset + delta, animated: false)
                    },
                    onEnd: { velocity in
                        settle(velocity: velocity, width: width)
                    }
                )
            )
        }
        .onDisappear { setOffset(0, animated: false) }
    }

    private func setOffset(_ value: CGFloat, animated: Bool) {
        if animated {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) { dragOffset = value }
        } else {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) { dragOffset = value }
        }
    }

    private func settle(velocity: CGFloat, width: CGFloat) {
        // Project where the strip would coast to, so a quick flick commits even if short.
        let projected = dragOffset + velocity * 0.18
        let step: Int
        if projected > width * 0.5 {
            step = -1            // dragged right → previous day
        } else if projected < -width * 0.5 {
            step = 1             // dragged left → next day
        } else {
            step = 0
        }

        if step != 0 {
            // Re-center the strip on the new day and compensate the offset by exactly one page,
            // so nothing visibly jumps, then let the spring carry it to rest.
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                coordinator.selectedDate = coordinator.selectedDate.addingDays(step)
                dragOffset += CGFloat(step) * width
            }
        }
        setOffset(0, animated: true)
    }
}

/// Listens for horizontally dominant, phased (trackpad) scroll events over its bounds.
/// Horizontal gestures are consumed so the vertical timeline doesn't scroll with them;
/// vertical gestures and plain mouse-wheel events pass through untouched.
private struct HorizontalSwipeMonitor: NSViewRepresentable {
    var isEnabled: Bool
    var onChange: (CGFloat) -> Void
    var onEnd: (CGFloat) -> Void

    func makeNSView(context: Context) -> MonitorView {
        let v = MonitorView()
        v.apply(self)
        return v
    }

    func updateNSView(_ nsView: MonitorView, context: Context) {
        nsView.apply(self)
    }

    static func dismantleNSView(_ nsView: MonitorView, coordinator: ()) {
        nsView.removeMonitor()
    }

    final class MonitorView: NSView {
        private var monitor: Any?
        private var isEnabled = true
        private var onChange: (CGFloat) -> Void = { _ in }
        private var onEnd: (CGFloat) -> Void = { _ in }

        private enum Axis { case undetermined, horizontal, vertical }
        private var axis: Axis = .undetermined
        private var accX: CGFloat = 0
        private var accY: CGFloat = 0
        private var samples: [(time: TimeInterval, dx: CGFloat)] = []
        private var swallowMomentum = false

        func apply(_ rep: HorizontalSwipeMonitor) {
            isEnabled = rep.isEnabled
            onChange = rep.onChange
            onEnd = rep.onEnd
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            removeMonitor()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self else { return event }
                return self.handle(event)   // nil swallows the event
            }
        }

        func removeMonitor() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        private func handle(_ event: NSEvent) -> NSEvent? {
            guard isEnabled, event.window === window, event.hasPreciseScrollingDeltas else { return event }
            let local = convert(event.locationInWindow, from: nil)
            guard bounds.contains(local) else { return event }

            let phase = event.phase
            let momentum = event.momentumPhase
            if phase.isEmpty && momentum.isEmpty { return event }   // classic wheel

            // Inertia after a horizontal swipe: swallow it so the timeline doesn't drift.
            if !momentum.isEmpty {
                guard swallowMomentum else { return event }
                if momentum.contains(.ended) || momentum.contains(.cancelled) { swallowMomentum = false }
                return nil
            }

            if phase.contains(.mayBegin) { return event }
            if phase.contains(.began) {
                axis = .undetermined
                accX = 0; accY = 0
                samples.removeAll()
                swallowMomentum = false
            }

            let dx = event.scrollingDeltaX
            let dy = event.scrollingDeltaY

            if phase.contains(.changed) || phase.contains(.began) {
                switch axis {
                case .undetermined:
                    accX += dx; accY += dy
                    if abs(accX) + abs(accY) > 3 {
                        if abs(accX) > abs(accY) * 1.2 {
                            axis = .horizontal
                            samples.append((event.timestamp, accX))
                            onChange(accX)
                            return nil
                        }
                        axis = .vertical
                    }
                    return event
                case .horizontal:
                    samples.append((event.timestamp, dx))
                    onChange(dx)
                    return nil
                case .vertical:
                    return event
                }
            }

            if phase.contains(.ended) || phase.contains(.cancelled) {
                defer { axis = .undetermined }
                guard axis == .horizontal else { return event }
                // Velocity over the last 100 ms before lift-off; a pause before release ⇒ 0,
                // which is what makes "stop mid-swipe and hold" settle by position alone.
                let cutoff = event.timestamp - 0.1
                let recent = samples.filter { $0.time >= cutoff }.reduce(0) { $0 + $1.dx }
                samples.removeAll()
                swallowMomentum = true
                onEnd(phase.contains(.cancelled) ? 0 : recent / 0.1)
                return nil
            }
            return axis == .horizontal ? nil : event
        }
    }
}
