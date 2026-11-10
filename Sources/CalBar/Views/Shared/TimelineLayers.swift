import SwiftUI

/// Hour (and half-hour) rules for the timeline.
///
/// Drawn into a single `Canvas` rather than a `VStack` of 24 `Rectangle`s: one display list
/// instead of ~50 layout-participating views, which is what keeps scrolling smooth at
/// Spacious density.
public struct HourGridLinesView: View {
    public let geometry: TimelineGeometry

    public init(geometry: TimelineGeometry) {
        self.geometry = geometry
    }

    public init(
        hourHeight: CGFloat,
        startHour: Int = 0,
        endHour: Int = 24,
        topPadding: CGFloat = 0,
        bottomPadding: CGFloat = 0
    ) {
        self.geometry = TimelineGeometry(
            startHour: startHour,
            endHour: endHour,
            hourHeight: hourHeight,
            topPadding: topPadding,
            bottomPadding: bottomPadding
        )
    }

    /// Half-hour rules only earn their keep when there's room to read them.
    private var showsHalfHours: Bool { geometry.hourHeight >= 48 }

    public var body: some View {
        Canvas(opaque: false, rendersAsynchronously: false) { context, size in
            let hourColor = GraphicsContext.Shading.color(Color.primary.opacity(0.09))
            let halfHourColor = GraphicsContext.Shading.color(Color.primary.opacity(0.045))
            let width = size.width

            var y = geometry.topPadding
            for _ in geometry.startHour..<geometry.endHour {
                context.fill(Path(CGRect(x: 0, y: y, width: width, height: 1)), with: hourColor)

                if showsHalfHours {
                    let midY = (y + geometry.hourHeight / 2).rounded()
                    context.fill(Path(CGRect(x: 0, y: midY, width: width, height: 1)), with: halfHourColor)
                }
                y += geometry.hourHeight
            }

            // Closing rule for a bounded window (e.g. the 5 PM line in working-hours mode).
            if geometry.endHour < 24 {
                context.fill(Path(CGRect(x: 0, y: y, width: width, height: 1)), with: hourColor)
            }
        }
        .frame(height: geometry.totalHeight)
        .allowsHitTesting(false)
    }
}

/// The red "now" rule. Driven by the coordinator's minute clock, so it actually advances
/// while the popover is open instead of freezing at the time the view was built.
public struct CurrentTimeIndicator: View {
    public let geometry: TimelineGeometry
    public let totalWidth: CGFloat
    public let currentMinute: Double
    public let showsKnob: Bool

    public init(
        geometry: TimelineGeometry,
        totalWidth: CGFloat,
        currentMinute: Double,
        showsKnob: Bool = true
    ) {
        self.geometry = geometry
        self.totalWidth = totalWidth
        self.currentMinute = currentMinute
        self.showsKnob = showsKnob
    }

    public var body: some View {
        if geometry.contains(minute: currentMinute) {
            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(GooglePalette.googleRed)
                    .frame(width: totalWidth, height: 1.5)

                if showsKnob {
                    Circle()
                        .fill(GooglePalette.googleRed)
                        .frame(width: 7, height: 7)
                        .offset(x: -3.5, y: -2.75)
                }
            }
            .compositingGroup()
            .shadow(color: GooglePalette.googleRed.opacity(0.35), radius: 2, y: 0.5)
            .offset(y: geometry.y(forMinute: currentMinute))
            .allowsHitTesting(false)
        }
    }
}

/// Grey-out for time that has already elapsed.
public struct PastTimeShade: View {
    public enum Extent: Equatable {
        case fullDay
        case upTo(minute: Double)
    }

    public let geometry: TimelineGeometry
    public let width: CGFloat
    public let extent: Extent
    public let color: Color
    public let opacity: Double

    public init(geometry: TimelineGeometry, width: CGFloat, extent: Extent, color: Color, opacity: Double) {
        self.geometry = geometry
        self.width = width
        self.extent = extent
        self.color = color
        self.opacity = opacity
    }

    private var height: CGFloat {
        switch extent {
        case .fullDay:
            return geometry.totalHeight
        case .upTo(let minute):
            return geometry.elapsedHeight(upTo: minute)
        }
    }

    public var body: some View {
        let shadeHeight = height
        if shadeHeight > 0 {
            Rectangle()
                .fill(color.opacity(opacity))
                .frame(width: width, height: shadeHeight)
                .allowsHitTesting(false)
        }
    }
}

/// Invisible per-hour anchors that `ScrollViewReader` targets.
public struct TimelineScrollAnchors: View {
    public let geometry: TimelineGeometry
    public let prefix: String

    public init(geometry: TimelineGeometry, prefix: String) {
        self.geometry = geometry
        self.prefix = prefix
    }

    public var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: geometry.topPadding)
            ForEach(geometry.startHour..<geometry.endHour, id: \.self) { hour in
                Color.clear
                    .frame(height: geometry.hourHeight)
                    .id("\(prefix)-hour-\(hour)")
            }
        }
        .allowsHitTesting(false)
    }
}

@MainActor
public enum TimelineScroller {
    /// Re-anchors a timeline on a given hour. Jumps without animation by default: when the
    /// popover is appearing, an animated scroll reads as the content sliding into place late.
    public static func scroll(
        _ proxy: ScrollViewProxy,
        prefix: String,
        hour: Int,
        animated: Bool = false
    ) {
        let anchorID = "\(prefix)-hour-\(hour)"

        if animated {
            withAnimation(.easeInOut(duration: 0.22)) {
                proxy.scrollTo(anchorID, anchor: .top)
            }
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                proxy.scrollTo(anchorID, anchor: .top)
            }
        }
    }

    /// Same as `scroll`, repeated once on the next run loop pass. The first attempt covers the
    /// common case; the retry covers the first-ever appearance, where the scroll view has not
    /// been laid out yet and `scrollTo` would otherwise be a no-op.
    public static func scrollSettling(
        _ proxy: ScrollViewProxy,
        prefix: String,
        hour: Int
    ) {
        scroll(proxy, prefix: prefix, hour: hour, animated: false)
        DispatchQueue.main.async {
            scroll(proxy, prefix: prefix, hour: hour, animated: false)
        }
    }
}
