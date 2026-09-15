import SwiftUI

public struct MenuBarPopoverView: View {
    @ObservedObject var coordinator: CalendarSyncCoordinator
    var onOpenSettings: () -> Void

    public init(coordinator: CalendarSyncCoordinator, onOpenSettings: @escaping () -> Void) {
        self.coordinator = coordinator
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header (Navigation, Mode Switcher, Actions)
                CalendarHeaderView(
                    coordinator: coordinator,
                    onOpenSettings: onOpenSettings
                )

                // Main Content View (Day or Week)
                Group {
                    if coordinator.viewMode == .day {
                        DayGridView(coordinator: coordinator)
                    } else {
                        WeekGridView(coordinator: coordinator)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Event Detail Modal Overlay
            if let selected = coordinator.selectedEventForDetail {
                Color.black.opacity(0.35)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            coordinator.selectedEventForDetail = nil
                        }
                    }

                EventDetailPopover(event: selected) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        coordinator.selectedEventForDetail = nil
                    }
                }
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
        .frame(
            width: coordinator.desiredPopoverSize().width,
            height: coordinator.desiredPopoverSize().height
        )
        .background(Color(nsColor: .windowBackgroundColor))
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: coordinator.viewMode)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: coordinator.limitWorkingHours)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: coordinator.timelineDensity)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: coordinator.onlyShowWeekdays)
    }
}
