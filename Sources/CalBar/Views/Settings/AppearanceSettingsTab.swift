import SwiftUI

public struct AppearanceSettingsTab: View {
    @ObservedObject var coordinator: CalendarSyncCoordinator

    public init(coordinator: CalendarSyncCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 20) {
                // Section: Timeline & Density
                GroupBox(label: Label("Timeline & Density", systemImage: "clock.arrow.circlepath").font(.system(size: 13, weight: .bold))) {
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle("Only show working hours (9:00 AM – 5:00 PM)", isOn: $coordinator.limitWorkingHours)
                            .font(.system(size: 12.5, weight: .medium))

                        Text("Clamps the Day and Week timeline grid to standard work hours (9 AM – 5 PM).")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        Toggle("Only show weekdays (Monday – Friday)", isOn: $coordinator.onlyShowWeekdays)
                            .font(.system(size: 12.5, weight: .medium))

                        Text("Hides Saturday and Sunday in Week view and navigates between workdays in Day view.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        Divider()

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Vertical Row Height / Density:")
                                .font(.system(size: 12, weight: .medium))

                            Picker("", selection: $coordinator.timelineDensity) {
                                ForEach(TimelineDensity.allCases) { density in
                                    Text(density.rawValue).tag(density)
                                }
                            }
                            .pickerStyle(.segmented)

                            HStack {
                                Text("Compact (38pt)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("Regular (52pt)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("Spacious (68pt)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(10)
                }

                // Section: Passed Time & Events Appearance
                GroupBox(label: Label("Passed Time & Events", systemImage: "hourglass.bottomhalf.filled").font(.system(size: 13, weight: .bold))) {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Shade passed time", isOn: $coordinator.shadePastTime)
                            .font(.system(size: 12.5, weight: .medium))

                        Text("Dims passed time on today and shades completed days in the Week view.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        if coordinator.shadePastTime {
                            Divider()

                            HStack(alignment: .center, spacing: 12) {
                                Text("Shading Color:")
                                    .font(.system(size: 12, weight: .medium))
                                    .frame(width: 100, alignment: .leading)

                                Picker("", selection: $coordinator.pastTimeColor) {
                                    ForEach(PastTimeColor.allCases) { colorOpt in
                                        HStack(spacing: 6) {
                                            Circle()
                                                .fill(colorOpt.color)
                                                .frame(width: 9, height: 9)
                                            Text(colorOpt.rawValue)
                                        }
                                        .tag(colorOpt)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 170)
                            }

                            HStack(alignment: .center, spacing: 12) {
                                Text("Shade Opacity:")
                                    .font(.system(size: 12, weight: .medium))
                                    .frame(width: 100, alignment: .leading)

                                Slider(value: $coordinator.pastTimeOpacity, in: 0.10...0.60, step: 0.05)

                                Text("\(Int(coordinator.pastTimeOpacity * 100))%")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .frame(width: 38, alignment: .trailing)
                            }
                        }

                        Divider()

                        // Passed Events Blur Level
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .center, spacing: 12) {
                                Text("Event Blur:")
                                    .font(.system(size: 12, weight: .medium))
                                    .frame(width: 100, alignment: .leading)

                                Slider(value: $coordinator.passedEventBlurRadius, in: 0...6, step: 0.5)

                                Text(blurLabel(coordinator.passedEventBlurRadius))
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .frame(width: 50, alignment: .trailing)
                            }

                            Text("Blurs completed events on past hours and days. Hovering over an event smoothly clears the blur.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Divider()

                        // Interactive Live Preview Swatch
                        HStack(spacing: 12) {
                            Text("Preview:")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .frame(width: 100, alignment: .leading)

                            ZStack(alignment: .leading) {
                                // Background mini calendar card
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(nsColor: .controlBackgroundColor))
                                    .frame(height: 28)

                                HStack(spacing: 6) {
                                    // Past event (shaded & blurred)
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(GooglePalette.googleBlue)
                                        Text("Past")
                                            .font(.system(size: 8.5, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    .frame(width: 54, height: 16)
                                    .blur(radius: coordinator.passedEventBlurRadius)
                                    .clipShape(RoundedRectangle(cornerRadius: 3))

                                    // Upcoming event (crisp)
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(GooglePalette.googleGreen)
                                        Text("Next")
                                            .font(.system(size: 8.5, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    .frame(width: 50, height: 16)
                                }
                                .padding(.leading, 8)

                                // Shading mask overlay (left 50%)
                                if coordinator.shadePastTime {
                                    GeometryReader { g in
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(coordinator.pastTimeColor.color.opacity(coordinator.pastTimeOpacity))
                                            .frame(width: g.size.width * 0.55)
                                    }
                                }
                            }
                            .frame(height: 28)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                        }
                    }
                    .padding(10)
                }

                // Section: Startup & Scroll Positioning
                GroupBox(label: Label("Timeline Position & Scroll", systemImage: "arrow.up.and.down.and.sparkles").font(.system(size: 13, weight: .bold))) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("When opening CalBar:")
                            .font(.system(size: 12, weight: .medium))

                        Picker("", selection: $coordinator.scrollBehavior) {
                            ForEach(TimelineScrollBehavior.allCases) { behavior in
                                Text(behavior.rawValue).tag(behavior)
                            }
                        }
                        .pickerStyle(.radioGroup)

                        if coordinator.scrollBehavior == .specificTime {
                            HStack(spacing: 10) {
                                Text("Target hour:")
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundColor(.secondary)

                                Picker("", selection: $coordinator.specificScrollHour) {
                                    ForEach(0..<24, id: \.self) { hour in
                                        Text(formattedHour(hour)).tag(hour)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 110)
                            }
                            .padding(.leading, 18)
                        } else if coordinator.scrollBehavior == .retainPosition {
                            Text("CalBar will keep your place and restore where you last scrolled.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .padding(.leading, 18)
                        }
                    }
                    .padding(10)
                }

                // Section: General Calendar Preferences
                GroupBox(label: Label("General Calendar Preferences", systemImage: "calendar.badge.clock").font(.system(size: 13, weight: .bold))) {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Start week on Monday", isOn: $coordinator.weekStartMonday)
                            .font(.system(size: 12))

                        HStack {
                            Text("Background refresh:")
                                .font(.system(size: 12))
                            Spacer()
                            Picker("", selection: $coordinator.refreshIntervalMinutes) {
                                Text("Every 1 minute").tag(1)
                                Text("Every 5 minutes").tag(5)
                                Text("Every 15 minutes").tag(15)
                                Text("Every 30 minutes").tag(30)
                            }
                            .pickerStyle(.menu)
                            .frame(width: 150)
                        }

                        if let lastSync = coordinator.lastSyncedAt {
                            HStack {
                                Text("Last synced:")
                                    .foregroundColor(.secondary)
                                Text(lastSync.formattedTime())
                                    .foregroundColor(.primary)
                            }
                            .font(.system(size: 11))
                        }
                    }
                    .padding(10)
                }

                // Section: Menu Bar Item
                GroupBox(label: Label("Menu Bar Item", systemImage: "menubar.rectangle").font(.system(size: 13, weight: .bold))) {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Status Bar Title", selection: $coordinator.menuBarDisplayMode) {
                            ForEach(MenuBarDisplayMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.radioGroup)
                    }
                    .padding(10)
                }
            }
            .padding(16)
        }
    }

    private func formattedHour(_ hour: Int) -> String {
        if hour == 0 { return "12:00 AM" }
        if hour < 12 { return "\(hour):00 AM" }
        if hour == 12 { return "12:00 PM" }
        return "\(hour - 12):00 PM"
    }

    private func blurLabel(_ radius: CGFloat) -> String {
        if radius == 0 {
            return "Off"
        }
        return String(format: "%.1f pt", radius)
    }
}
