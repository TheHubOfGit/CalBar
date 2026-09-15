import SwiftUI

public struct CalendarSelectionTab: View {
    @ObservedObject var coordinator: CalendarSyncCoordinator

    public init(coordinator: CalendarSyncCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header bar with counts and Select All / Deselect All
            HStack {
                let selectedCount = coordinator.calendars.filter { $0.isSelected }.count
                Text("Select Calendars to Show (\(selectedCount) of \(coordinator.calendars.count))")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Button("Select All") {
                    for i in 0..<coordinator.calendars.count {
                        coordinator.calendars[i].isSelected = true
                    }
                    saveAndRefresh()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(GooglePalette.googleBlue)

                Text("•")
                    .foregroundColor(.secondary)

                Button("Deselect All") {
                    for i in 0..<coordinator.calendars.count {
                        coordinator.calendars[i].isSelected = false
                    }
                    saveAndRefresh()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(GooglePalette.googleBlue)
            }
            .padding(.bottom, 4)

            if coordinator.calendars.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No calendars found for current sync provider.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Button("Refresh Calendars") {
                        Task { await coordinator.refreshAll() }
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(coordinator.calendars) { cal in
                        HStack(spacing: 10) {
                            Toggle(isOn: Binding(
                                get: { cal.isSelected },
                                set: { _ in
                                    coordinator.toggleCalendarSelection(id: cal.id)
                                }
                            )) {
                                EmptyView()
                            }
                            .toggleStyle(.checkbox)

                            // Calendar color swatch
                            Circle()
                                .fill(Color(hex: cal.colorHex))
                                .frame(width: 12, height: 12)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(cal.summary)
                                        .font(.system(size: 12.5, weight: .medium))
                                        .foregroundColor(.primary)

                                    if cal.isPrimary {
                                        Text("Primary")
                                            .font(.system(size: 9, weight: .bold))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(GooglePalette.googleBlue.opacity(0.15))
                                            .foregroundColor(GooglePalette.googleBlue)
                                            .cornerRadius(3)
                                    }
                                }

                                if let role = cal.accessRole, role != "owner" {
                                    Text(role.capitalized)
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()
                        }
                        .padding(.vertical, 3)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
            }
        }
        .padding(16)
    }

    private func saveAndRefresh() {
        let selectedIds = coordinator.calendars.filter { $0.isSelected }.map { $0.id }
        UserDefaults.standard.set(selectedIds, forKey: "calbar_selected_cals_\(coordinator.syncProvider.rawValue)")
        Task { await coordinator.fetchEventsForCurrentRange() }
    }
}
