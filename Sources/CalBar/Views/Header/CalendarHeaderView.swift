import SwiftUI

public struct CalendarHeaderView: View {
    @ObservedObject var coordinator: CalendarSyncCoordinator
    var onOpenSettings: () -> Void

    public init(coordinator: CalendarSyncCoordinator, onOpenSettings: @escaping () -> Void) {
        self.coordinator = coordinator
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        HStack(spacing: 8) {
            // Navigation Group: [ < | Today | > ]
            HStack(spacing: 1) {
                Button(action: { coordinator.prevPage() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10.5, weight: .semibold))
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(action: { coordinator.goToToday() }) {
                    Text("Today")
                        .font(.system(size: 11.5, weight: .medium))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                }
                .buttonStyle(.plain)

                Button(action: { coordinator.nextPage() }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10.5, weight: .semibold))
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 1)
            .background(Color.primary.opacity(0.06))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 0.8)
            )

            // Date / Month Title
            Text(headerTitle)
                .font(.system(size: 13.5, weight: .bold))
                .lineLimit(1)
                .foregroundColor(.primary)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 4)

            // Single-click View Mode Switcher: Day | Week
            HStack(spacing: 0) {
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        coordinator.viewMode = .day
                    }
                }) {
                    Text("Day")
                        .font(.system(size: 11, weight: coordinator.viewMode == .day ? .bold : .medium))
                        .foregroundColor(coordinator.viewMode == .day ? .white : .primary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3.5)
                        .background(
                            coordinator.viewMode == .day ?
                                RoundedRectangle(cornerRadius: 4).fill(GooglePalette.googleBlue) :
                                nil
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        coordinator.viewMode = .week
                    }
                }) {
                    Text("Week")
                        .font(.system(size: 11, weight: coordinator.viewMode == .week ? .bold : .medium))
                        .foregroundColor(coordinator.viewMode == .week ? .white : .primary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3.5)
                        .background(
                            coordinator.viewMode == .week ?
                                RoundedRectangle(cornerRadius: 4).fill(GooglePalette.googleBlue) :
                                nil
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(2)
            .background(Color.primary.opacity(0.08))
            .cornerRadius(6)

            // Actions: Refresh + Settings
            HStack(spacing: 2) {
                Button(action: {
                    Task { await coordinator.refreshAll() }
                }) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11.5))
                        .rotationEffect(Angle(degrees: coordinator.isSyncing ? 360 : 0))
                        .animation(coordinator.isSyncing ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: coordinator.isSyncing)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Refresh Calendars")

                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11.5))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Material.bar)
        .overlay(
            Divider(), alignment: .bottom
        )
    }

    private var headerTitle: String {
        if coordinator.viewMode == .day {
            return coordinator.selectedDate.formattedDayHeader()
        } else {
            return coordinator.selectedDate.formattedMonthYear()
        }
    }
}
