import Testing
import Foundation
@testable import CalBar

/// Covers the behavior that makes the popover open on the *current* day: the app process is
/// long-lived, so `selectedDate` goes stale as soon as the user navigates away or the clock
/// rolls past midnight.
@MainActor
struct CoordinatorPresentationTests {
    private func makeCoordinator() -> CalendarSyncCoordinator {
        let coordinator = CalendarSyncCoordinator.shared
        coordinator.scrollBehavior = .currentTime
        coordinator.limitWorkingHours = false
        coordinator.selectedDate = Date()
        return coordinator
    }

    @Test func presentationSnapsBackToTodayAfterNavigatingAway() {
        let coordinator = makeCoordinator()
        coordinator.selectedDate = Date().addingDays(-5)
        #expect(coordinator.isShowingToday == false)

        coordinator.prepareForPopoverPresentation()

        #expect(coordinator.isShowingToday)
    }

    @Test func presentationAlwaysRequestsAFreshScrollAnchor() {
        let coordinator = makeCoordinator()
        let before = coordinator.scrollRequestToken

        // Already on today: the date doesn't change, but the timeline must still re-anchor,
        // otherwise a popover reopened hours later stays parked at the old scroll position.
        coordinator.prepareForPopoverPresentation()

        #expect(coordinator.scrollRequestToken > before)
    }

    @Test func goToTodayReAnchorsEvenWhenAlreadyOnToday() {
        let coordinator = makeCoordinator()
        let before = coordinator.scrollRequestToken

        coordinator.goToToday()

        #expect(coordinator.isShowingToday)
        #expect(coordinator.scrollRequestToken > before)
    }

    @Test func scrollTargetKeepsAnHourOfContextAboveNow() {
        let coordinator = makeCoordinator()
        coordinator.currentMinute = 14 * 60 + 20   // 2:20 PM

        #expect(coordinator.targetScrollHour(isToday: true) == 13)
    }

    @Test func scrollTargetStaysInsideTheWorkingHoursWindow() {
        let coordinator = makeCoordinator()
        coordinator.limitWorkingHours = true       // 9 AM - 5 PM

        coordinator.currentMinute = 2 * 60         // before the window opens
        #expect(coordinator.targetScrollHour(isToday: true) == 9)

        coordinator.currentMinute = 23 * 60        // after it closes
        #expect(coordinator.targetScrollHour(isToday: true) == 16)

        coordinator.limitWorkingHours = false
    }

    @Test func scrollTargetFallsBackToMorningOnOtherDays() {
        let coordinator = makeCoordinator()
        coordinator.currentMinute = 22 * 60

        #expect(coordinator.targetScrollHour(isToday: false) == 9)
    }

    @Test func specificHourBehaviorIsClampedToTheVisibleWindow() {
        let coordinator = makeCoordinator()
        coordinator.scrollBehavior = .specificTime
        coordinator.specificScrollHour = 22
        coordinator.limitWorkingHours = true

        #expect(coordinator.targetScrollHour(isToday: true) == 16)

        coordinator.limitWorkingHours = false
        coordinator.scrollBehavior = .currentTime
    }

    @Test func switchingViewModeDoesNotChangeTheFetchedRange() {
        let coordinator = makeCoordinator()
        let dayRange = coordinator.dateRangeForCurrentView()

        coordinator.viewMode = .week
        let weekRange = coordinator.dateRangeForCurrentView()
        coordinator.viewMode = .day

        // This is what lets the Day/Week toggle avoid a network round trip entirely.
        #expect(dayRange.start == weekRange.start)
        #expect(dayRange.end == weekRange.end)
    }
}
