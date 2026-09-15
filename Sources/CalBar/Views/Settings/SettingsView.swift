import SwiftUI

public enum SettingsTab: String, CaseIterable, Identifiable {
    case accounts = "Accounts"
    case calendars = "Calendars"
    case appearance = "General"

    public var id: String { rawValue }

    var icon: String {
        switch self {
        case .accounts: return "person.crop.circle"
        case .calendars: return "calendar"
        case .appearance: return "gearshape"
        }
    }
}

public struct SettingsView: View {
    @ObservedObject var coordinator: CalendarSyncCoordinator
    @State private var currentTab: SettingsTab = .accounts

    public init(coordinator: CalendarSyncCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Clean Segmented Tab Navigation
            HStack {
                Picker("", selection: $currentTab) {
                    ForEach(SettingsTab.allCases) { tab in
                        Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)

                Spacer()

                Button("Quit CalBar") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(.red)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Material.bar)
            .overlay(Divider(), alignment: .bottom)

            // Tab Content
            Group {
                switch currentTab {
                case .accounts:
                    AccountsSettingsTab(coordinator: coordinator)
                case .calendars:
                    CalendarSelectionTab(coordinator: coordinator)
                case .appearance:
                    AppearanceSettingsTab(coordinator: coordinator)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 520, height: 520)
    }
}
