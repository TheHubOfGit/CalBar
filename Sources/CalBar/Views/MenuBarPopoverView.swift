import SwiftUI

public struct MenuBarPopoverView: View {
    @ObservedObject var coordinator: CalendarSyncCoordinator
    var onOpenSettings: () -> Void

    public init(coordinator: CalendarSyncCoordinator, onOpenSettings: @escaping () -> Void) {
        self.coordinator = coordinator
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        // Resolved once per render: this drives the SwiftUI frame, and `MenuBarController`
        // animates the AppKit `contentSize` to match.
        let size = coordinator.desiredPopoverSize()

        ZStack {
            VStack(spacing: 0) {
                CalendarHeaderView(
                    coordinator: coordinator,
                    onOpenSettings: onOpenSettings
                )

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if let selected = coordinator.selectedEventForDetail {
                detailOverlay(for: selected)
            }
        }
        .frame(width: size.width, height: size.height)
        .background(Color(nsColor: .windowBackgroundColor))
        .background(keyboardShortcuts)
        // Only intercept Escape while the detail sheet is up; otherwise Escape must keep its
        // normal job of dismissing the popover itself.
        .modifier(EscapeToDismissDetail(isActive: coordinator.selectedEventForDetail != nil) {
            coordinator.dismissDetail()
        })
    }

    /// Day and Week crossfade in place. The popover is simultaneously resizing itself, so a
    /// spring on the whole tree made the two animations fight; a short opacity blend reads as
    /// one smooth change.
    @ViewBuilder
    private var content: some View {
        ZStack {
            if coordinator.viewMode == .day {
                DayPagerView(coordinator: coordinator)
                    .transition(.opacity)
            } else {
                WeekGridView(coordinator: coordinator)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.16), value: coordinator.viewMode)
    }

    @ViewBuilder
    private func detailOverlay(for event: CalendarEvent) -> some View {
        Color.black.opacity(0.32)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture { coordinator.dismissDetail() }
            .transition(.opacity)

        EventDetailPopover(event: event) {
            coordinator.dismissDetail()
        }
        .transition(.scale(scale: 0.94).combined(with: .opacity))
    }

    /// Hidden buttons that exist purely to register key equivalents with the responder chain.
    private var keyboardShortcuts: some View {
        ZStack {
            Button("Previous") { coordinator.prevPage() }
                .keyboardShortcut(.leftArrow, modifiers: [])
            Button("Next") { coordinator.nextPage() }
                .keyboardShortcut(.rightArrow, modifiers: [])
            Button("Today") { coordinator.goToToday() }
                .keyboardShortcut("t", modifiers: [])
            Button("Day View") { coordinator.viewMode = .day }
                .keyboardShortcut("d", modifiers: [])
            Button("Week View") { coordinator.viewMode = .week }
                .keyboardShortcut("w", modifiers: [])
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }
}

private struct EscapeToDismissDetail: ViewModifier {
    let isActive: Bool
    let onDismiss: () -> Void

    func body(content: Content) -> some View {
        if isActive {
            content.onExitCommand(perform: onDismiss)
        } else {
            content
        }
    }
}
