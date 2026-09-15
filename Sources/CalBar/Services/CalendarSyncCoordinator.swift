import Foundation
import SwiftUI
import Combine

public enum SyncProvider: String, CaseIterable, Identifiable, Codable {
    case googleDirect = "Google Calendar (OAuth)"
    case eventKit = "macOS System Calendars"
    case sample = "Demo / Sample Calendars"

    public var id: String { rawValue }
}

public enum MenuBarDisplayMode: String, CaseIterable, Identifiable, Codable {
    case iconOnly = "Calendar Icon"
    case iconWithDate = "Icon + Day of Month"
    case nextEvent = "Next Meeting Countdown"

    public var id: String { rawValue }
}

@MainActor
public final class CalendarSyncCoordinator: ObservableObject {
    public static let shared = CalendarSyncCoordinator()

    // Navigation & View Mode
    @Published public var selectedDate: Date = Date() {
        didSet {
            Task { await fetchEventsForCurrentRange() }
        }
    }
    @Published public var viewMode: ViewMode = .day {
        didSet {
            Task { await fetchEventsForCurrentRange() }
        }
    }
    @Published public var selectedEventForDetail: CalendarEvent? = nil

    // Sync State
    @Published public var syncProvider: SyncProvider = .sample {
        didSet {
            UserDefaults.standard.set(syncProvider.rawValue, forKey: "calbar_sync_provider")
            Task { await refreshAll() }
        }
    }
    @Published public var calendars: [CalendarItem] = []
    @Published public var events: [CalendarEvent] = [] {
        didSet {
            updatePositionedEvents()
        }
    }
    @Published public var isSyncing: Bool = false
    @Published public var lastSyncedAt: Date? = nil
    @Published public var statusMessage: String? = nil

    // Performance: Precomputed Layout Memoization (Zero CPU churn on scroll/render)
    @Published public private(set) var positionedEventsByDayKey: [String: [PositionedEvent]] = [:]

    // Battery Optimization: Active Minute Clock (Suspended when popover is closed)
    @Published public var currentMinute: Double = Date().minuteOfDay
    @Published public var isPopoverVisible: Bool = false {
        didSet {
            if isPopoverVisible {
                currentMinute = Date().minuteOfDay
                startMinuteTimer()
            } else {
                stopMinuteTimer()
            }
        }
    }

    // Preferences
    @Published public var menuBarDisplayMode: MenuBarDisplayMode = .iconWithDate {
        didSet {
            UserDefaults.standard.set(menuBarDisplayMode.rawValue, forKey: "calbar_menu_display_mode")
            onMenuBarTitleChanged?(menuBarTitle)
        }
    }
    @Published public var weekStartMonday: Bool = false {
        didSet {
            UserDefaults.standard.set(weekStartMonday, forKey: "calbar_week_start_monday")
            Task { await fetchEventsForCurrentRange() }
        }
    }
    @Published public var refreshIntervalMinutes: Int = 5 {
        didSet {
            UserDefaults.standard.set(refreshIntervalMinutes, forKey: "calbar_refresh_interval")
            restartTimer()
        }
    }

    // Appearance & Layout Preferences
    @Published public var limitWorkingHours: Bool = false {
        didSet {
            UserDefaults.standard.set(limitWorkingHours, forKey: "calbar_limit_working_hours")
            onPopoverSizeChanged?(desiredPopoverSize())
        }
    }
    @Published public var onlyShowWeekdays: Bool = false {
        didSet {
            UserDefaults.standard.set(onlyShowWeekdays, forKey: "calbar_only_show_weekdays")
            onPopoverSizeChanged?(desiredPopoverSize())
        }
    }
    @Published public var timelineDensity: TimelineDensity = .regular {
        didSet {
            UserDefaults.standard.set(timelineDensity.rawValue, forKey: "calbar_timeline_density")
            onPopoverSizeChanged?(desiredPopoverSize())
        }
    }
    @Published public var shadePastTime: Bool = true {
        didSet {
            UserDefaults.standard.set(shadePastTime, forKey: "calbar_shade_past_time")
        }
    }
    @Published public var pastTimeColor: PastTimeColor = .gray {
        didSet {
            UserDefaults.standard.set(pastTimeColor.rawValue, forKey: "calbar_past_time_color")
        }
    }
    @Published public var pastTimeOpacity: Double = 0.20 {
        didSet {
            UserDefaults.standard.set(pastTimeOpacity, forKey: "calbar_past_time_opacity")
        }
    }
    @Published public var passedEventBlurRadius: CGFloat = 0.0 {
        didSet {
            UserDefaults.standard.set(Double(passedEventBlurRadius), forKey: "calbar_passed_event_blur")
        }
    }
    @Published public var scrollBehavior: TimelineScrollBehavior = .currentTime {
        didSet {
            UserDefaults.standard.set(scrollBehavior.rawValue, forKey: "calbar_scroll_behavior")
        }
    }
    @Published public var specificScrollHour: Int = 9 {
        didSet {
            UserDefaults.standard.set(specificScrollHour, forKey: "calbar_specific_scroll_hour")
        }
    }
    public var lastScrollHour: Int = 9

    public var onMenuBarTitleChanged: (@MainActor (String) -> Void)?
    public var onPopoverSizeChanged: (@MainActor (NSSize) -> Void)?

    // MARK: - Timeline & Popover Geometry Computations
    public var currentHourHeight: CGFloat {
        timelineDensity.hourHeight
    }

    public var timelineStartHour: Int {
        limitWorkingHours ? 9 : 0
    }

    public var timelineEndHour: Int {
        limitWorkingHours ? 17 : 24
    }

    public var totalTimelineHours: Int {
        max(1, timelineEndHour - timelineStartHour)
    }

    public var timelineTopPadding: CGFloat { 8.0 }
    public var timelineBottomPadding: CGFloat { 16.0 }

    public var totalTimelineCanvasHeight: CGFloat {
        timelineTopPadding + CGFloat(totalTimelineHours) * currentHourHeight + timelineBottomPadding
    }

    public var currentWeekDays: [Date] {
        let all7 = selectedDate.daysOfWeek(firstWeekday: weekStartMonday ? 2 : 1)
        if onlyShowWeekdays {
            let cal = Calendar.current
            return all7.filter { date in
                let wd = cal.component(.weekday, from: date)
                return wd != 1 && wd != 7
            }
        }
        return all7
    }

    public func desiredPopoverSize() -> NSSize {
        let width: CGFloat
        if viewMode == .day {
            width = 420
        } else {
            width = onlyShowWeekdays ? 660 : 820
        }

        let height: CGFloat
        if limitWorkingHours {
            height = min(620, max(460, 96 + CGFloat(totalTimelineHours) * currentHourHeight))
        } else {
            height = 540
        }
        return NSSize(width: width, height: height)
    }

    public func targetScrollHour(isToday: Bool) -> Int {
        switch scrollBehavior {
        case .currentTime:
            if isToday {
                let currentHour = Calendar.current.component(.hour, from: Date())
                return max(timelineStartHour, min(timelineEndHour - 1, currentHour - 1))
            } else {
                return max(timelineStartHour, min(timelineEndHour - 1, 9))
            }
        case .specificTime:
            return max(timelineStartHour, min(timelineEndHour - 1, specificScrollHour))
        case .retainPosition:
            return max(timelineStartHour, min(timelineEndHour - 1, lastScrollHour))
        }
    }

    private var syncTimer: Timer?
    private var minuteTimer: Timer?
    private let authService = GoogleAuthService.shared
    private let calendarService = GoogleCalendarService.shared
    private let eventKitService = EventKitService.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Load saved preferences
        if let savedProvider = UserDefaults.standard.string(forKey: "calbar_sync_provider"),
           let provider = SyncProvider(rawValue: savedProvider) {
            self.syncProvider = provider
        }
        if let savedMode = UserDefaults.standard.string(forKey: "calbar_menu_display_mode"),
           let mode = MenuBarDisplayMode(rawValue: savedMode) {
            self.menuBarDisplayMode = mode
        }
        self.weekStartMonday = UserDefaults.standard.bool(forKey: "calbar_week_start_monday")
        let savedInterval = UserDefaults.standard.integer(forKey: "calbar_refresh_interval")
        self.refreshIntervalMinutes = savedInterval > 0 ? savedInterval : 5

        self.limitWorkingHours = UserDefaults.standard.bool(forKey: "calbar_limit_working_hours")
        self.onlyShowWeekdays = UserDefaults.standard.bool(forKey: "calbar_only_show_weekdays")
        if let densityStr = UserDefaults.standard.string(forKey: "calbar_timeline_density"),
           let density = TimelineDensity(rawValue: densityStr) {
            self.timelineDensity = density
        }
        if UserDefaults.standard.object(forKey: "calbar_shade_past_time") != nil {
            self.shadePastTime = UserDefaults.standard.bool(forKey: "calbar_shade_past_time")
        }
        if let colorStr = UserDefaults.standard.string(forKey: "calbar_past_time_color"),
           let color = PastTimeColor(rawValue: colorStr) {
            self.pastTimeColor = color
        }
        let savedOpacity = UserDefaults.standard.double(forKey: "calbar_past_time_opacity")
        if savedOpacity > 0 {
            self.pastTimeOpacity = savedOpacity
        }
        let savedBlur = UserDefaults.standard.double(forKey: "calbar_passed_event_blur")
        self.passedEventBlurRadius = CGFloat(savedBlur)
        if let scrollStr = UserDefaults.standard.string(forKey: "calbar_scroll_behavior"),
           let behavior = TimelineScrollBehavior(rawValue: scrollStr) {
            self.scrollBehavior = behavior
        }
        let savedHour = UserDefaults.standard.integer(forKey: "calbar_specific_scroll_hour")
        if savedHour > 0 || UserDefaults.standard.object(forKey: "calbar_specific_scroll_hour") != nil {
            self.specificScrollHour = savedHour
        }

        setupEventKitObservation()

        // Initial fetch
        Task {
            await refreshAll()
            restartTimer()
        }
    }

    private func setupEventKitObservation() {
        NotificationCenter.default.publisher(for: .EKEventStoreChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self, self.syncProvider == .eventKit else { return }
                Task { @MainActor in
                    await self.fetchEventsForCurrentRange()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Memoized Layout Lookup
    public func positionedEvents(for date: Date) -> [PositionedEvent] {
        positionedEventsByDayKey[date.dayKeyString] ?? []
    }

    private func updatePositionedEvents() {
        var grouped: [String: [CalendarEvent]] = [:]
        for event in events where !event.isAllDay {
            let key = event.start.dayKeyString
            grouped[key, default: []].append(event)
        }

        var result: [String: [PositionedEvent]] = [:]
        for (key, dayEvs) in grouped {
            result[key] = EventLayoutAlgorithm.layoutEvents(dayEvs)
        }
        self.positionedEventsByDayKey = result
    }

    // MARK: - Live Minute Clock (Active only when popover is open)
    private func startMinuteTimer() {
        minuteTimer?.invalidate()
        minuteTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.currentMinute = Date().minuteOfDay
                self?.onMenuBarTitleChanged?(self?.menuBarTitle ?? "")
            }
        }
    }

    private func stopMinuteTimer() {
        minuteTimer?.invalidate()
        minuteTimer = nil
    }

    // MARK: - Navigation
    public func goToToday() {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedDate = Date()
        }
    }

    public func nextPage() {
        withAnimation(.easeInOut(duration: 0.2)) {
            let step = (viewMode == .day) ? 1 : 7
            selectedDate = selectedDate.addingDays(step)
        }
    }

    public func prevPage() {
        withAnimation(.easeInOut(duration: 0.2)) {
            let step = (viewMode == .day) ? 1 : 7
            selectedDate = selectedDate.addingDays(-step)
        }
    }

    // MARK: - Sync & Data
    public func refreshAll() async {
        isSyncing = true
        defer { isSyncing = false }

        switch syncProvider {
        case .sample:
            if calendars.isEmpty {
                self.calendars = SampleDataService.sampleCalendars()
            }
            self.events = loadSampleEvents()
            lastSyncedAt = Date()

        case .eventKit:
            if !eventKitService.hasAccess {
                _ = await eventKitService.requestAccess()
            }
            if eventKitService.hasAccess {
                let fetchedCals = eventKitService.fetchCalendars()
                syncCalendarSelectionState(newCalendars: fetchedCals)
                await fetchEventsForCurrentRange()
                lastSyncedAt = Date()
            } else {
                statusMessage = "Calendar access not granted in macOS System Settings."
            }

        case .googleDirect:
            if authService.isSignedIn, let token = await authService.getValidAccessToken() {
                do {
                    let fetchedCals = try await calendarService.fetchCalendarList(accessToken: token)
                    syncCalendarSelectionState(newCalendars: fetchedCals)
                    await fetchEventsForCurrentRange()
                    lastSyncedAt = Date()
                } catch {
                    statusMessage = "Google sync error: \(error.localizedDescription)"
                }
            } else {
                statusMessage = "Sign in with Google in Settings to sync."
            }
        }

        onMenuBarTitleChanged?(menuBarTitle)
    }

    public func toggleCalendarSelection(id: String) {
        if let index = calendars.firstIndex(where: { $0.id == id }) {
            calendars[index].isSelected.toggle()
            saveSelectedCalendarIds()
            Task { await fetchEventsForCurrentRange() }
        }
    }

    private func saveSelectedCalendarIds() {
        let selectedIds = calendars.filter { $0.isSelected }.map { $0.id }
        UserDefaults.standard.set(selectedIds, forKey: "calbar_selected_cals_\(syncProvider.rawValue)")
    }

    private func syncCalendarSelectionState(newCalendars: [CalendarItem]) {
        let savedSelected = UserDefaults.standard.stringArray(forKey: "calbar_selected_cals_\(syncProvider.rawValue)")
        self.calendars = newCalendars.map { cal in
            var copy = cal
            if let saved = savedSelected {
                copy.isSelected = saved.contains(cal.id)
            }
            return copy
        }
    }

    public func fetchEventsForCurrentRange() async {
        let range = dateRangeForCurrentView()
        let selectedCalendarIds = calendars.filter { $0.isSelected }.map { $0.id }
        let calColorMap = Dictionary(calendars.map { ($0.id, $0.colorHex) }, uniquingKeysWith: { first, _ in first })

        var fetched: [CalendarEvent] = []
        switch syncProvider {
        case .sample:
            fetched = loadSampleEvents()

        case .eventKit:
            if eventKitService.hasAccess {
                fetched = eventKitService.fetchEvents(
                    calendarIds: selectedCalendarIds,
                    start: range.start,
                    end: range.end
                )
            }

        case .googleDirect:
            guard authService.isSignedIn, let token = await authService.getValidAccessToken() else { return }
            var allEvents: [CalendarEvent] = []
            for cal in calendars where cal.isSelected {
                if let evs = try? await calendarService.fetchEvents(
                    calendarId: cal.id,
                    start: range.start,
                    end: range.end,
                    calendarColorHex: cal.colorHex,
                    accessToken: token
                ) {
                    allEvents.append(contentsOf: evs)
                }
            }
            fetched = allEvents
        }

        // Attach parent calendar color if event has no specific color
        self.events = fetched.map { ev in
            var copy = ev
            if let calColor = calColorMap[copy.calendarId], !calColor.isEmpty {
                copy.calendarColorHex = calColor
            }
            return copy
        }

        onMenuBarTitleChanged?(menuBarTitle)
    }

    private func loadSampleEvents() -> [CalendarEvent] {
        let activeCalIds = Set(calendars.filter { $0.isSelected }.map { $0.id })
        var sampled: [CalendarEvent] = []
        let days = selectedDate.daysOfWeek(firstWeekday: weekStartMonday ? 2 : 1)
        for day in days {
            sampled.append(contentsOf: SampleDataService.sampleEvents(for: day))
        }
        return sampled.filter { activeCalIds.contains($0.calendarId) }
    }

    public func dateRangeForCurrentView() -> (start: Date, end: Date) {
        let firstWeekday = weekStartMonday ? 2 : 1
        let start = selectedDate.startOfWeek(firstWeekday: firstWeekday).startOfDay()
        let end = start.addingDays(7).endOfDay()
        return (start, end)
    }

    // MARK: - Menu Bar Title & Next Meeting
    public var nextUpcomingEvent: CalendarEvent? {
        let now = Date()
        let upcoming = events
            .filter { !$0.isAllDay && $0.end > now && $0.start <= now.addingTimeInterval(3600 * 4) }
            .sorted { $0.start < $1.start }
        return upcoming.first
    }

    public var menuBarTitle: String {
        switch menuBarDisplayMode {
        case .iconOnly:
            return ""
        case .iconWithDate:
            return Date().formattedDayNumber()
        case .nextEvent:
            if let next = nextUpcomingEvent {
                let now = Date()
                if next.isHappeningNow {
                    return "Now: \(next.summary)"
                }
                let diffMin = Int(max(1, next.start.timeIntervalSince(now) / 60))
                return "in \(diffMin)m: \(next.summary)"
            }
            return Date().formattedDayNumber()
        }
    }

    private func restartTimer() {
        syncTimer?.invalidate()
        let seconds = TimeInterval(max(60, refreshIntervalMinutes * 60))
        syncTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshAll()
            }
        }
    }
}
