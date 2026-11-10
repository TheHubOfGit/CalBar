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
            navigationCluster

            Text(headerTitle)
                .font(.system(size: 13.5, weight: .bold))
                .lineLimit(1)
                .foregroundColor(.primary)
                .minimumScaleFactor(0.8)
                .animation(.easeInOut(duration: 0.14), value: headerTitle)

            Spacer(minLength: 4)

            modeSwitcher

            HStack(spacing: 2) {
                HeaderIconButton(
                    systemName: "arrow.triangle.2.circlepath",
                    help: "Refresh Calendars",
                    isSpinning: coordinator.isSyncing
                ) {
                    Task { await coordinator.refreshAll() }
                }

                HeaderIconButton(systemName: "gearshape", help: "Settings", action: onOpenSettings)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Material.bar)
        .overlay(Divider(), alignment: .bottom)
    }

    // MARK: - Navigation

    private var navigationCluster: some View {
        HStack(spacing: 1) {
            HeaderIconButton(systemName: "chevron.left", help: "Previous", size: 10.5) {
                coordinator.prevPage()
            }

            Button(action: { coordinator.goToToday() }) {
                Text("Today")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(coordinator.isShowingToday ? .secondary : .primary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Jump to today")

            HeaderIconButton(systemName: "chevron.right", help: "Next", size: 10.5) {
                coordinator.nextPage()
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 1)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.8)
        )
    }

    // MARK: - Day / Week switcher

    private var modeSwitcher: some View {
        HStack(spacing: 0) {
            ForEach(ViewMode.allCases) { mode in
                modeButton(mode)
            }
        }
        .padding(2)
        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    @ViewBuilder
    private func modeButton(_ mode: ViewMode) -> some View {
        let isSelected = coordinator.viewMode == mode

        Button {
            guard !isSelected else { return }
            coordinator.viewMode = mode
        } label: {
            Text(mode.rawValue)
                .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 9)
                .padding(.vertical, 3.5)
                .background {
                    if isSelected {
                        // A single shared geometry element slides between the two segments
                        // instead of one fading out while the other fades in.
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(GooglePalette.googleBlue)
                            .matchedGeometryEffect(id: "modeSelection", in: modeNamespace)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.26, dampingFraction: 0.85), value: coordinator.viewMode)
    }

    @Namespace private var modeNamespace

    private var headerTitle: String {
        coordinator.viewMode == .day
            ? coordinator.selectedDate.formattedDayHeader()
            : coordinator.selectedDate.formattedMonthYear()
    }
}

/// Small icon button with a hover affordance — the old plain buttons gave no feedback at all.
private struct HeaderIconButton: View {
    let systemName: String
    let help: String
    var size: CGFloat = 11.5
    var isSpinning: Bool = false
    let action: () -> Void

    @State private var isHovered = false
    @State private var rotation: Double = 0

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .semibold))
                .rotationEffect(.degrees(rotation))
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.primary.opacity(isHovered ? 0.1 : 0))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .help(help)
        .onAppear {
            if isSpinning { startSpinning() }
        }
        .onChange(of: isSpinning) { _, spinning in
            if spinning {
                startSpinning()
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    rotation = 0
                }
            }
        }
    }

    private func startSpinning() {
        withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
            rotation = 360
        }
    }
}
