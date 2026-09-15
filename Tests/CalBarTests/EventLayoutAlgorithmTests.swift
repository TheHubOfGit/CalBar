import XCTest
@testable import CalBar

final class EventLayoutAlgorithmTests: XCTestCase {
    func testSingleEventTakesFullWidth() {
        let base = Date()
        let event = CalendarEvent(
            id: "1",
            calendarId: "cal1",
            summary: "Single Meeting",
            start: base,
            end: base.addingTimeInterval(3600)
        )

        let positioned = EventLayoutAlgorithm.layoutEvents([event])
        XCTAssertEqual(positioned.count, 1)
        XCTAssertEqual(positioned[0].column, 0)
        XCTAssertEqual(positioned[0].totalColumns, 1)
        XCTAssertEqual(positioned[0].widthFraction, 1.0)
        XCTAssertEqual(positioned[0].leftFraction, 0.0)
    }

    func testTwoOverlappingEventsSplitEqually() {
        let base = Date()
        let event1 = CalendarEvent(
            id: "1",
            calendarId: "cal1",
            summary: "Meeting 1",
            start: base,
            end: base.addingTimeInterval(3600)
        )
        let event2 = CalendarEvent(
            id: "2",
            calendarId: "cal1",
            summary: "Meeting 2",
            start: base.addingTimeInterval(1800), // starts halfway through
            end: base.addingTimeInterval(5400)
        )

        let positioned = EventLayoutAlgorithm.layoutEvents([event1, event2])
        XCTAssertEqual(positioned.count, 2)
        XCTAssertEqual(positioned[0].column, 0)
        XCTAssertEqual(positioned[0].totalColumns, 2)
        XCTAssertEqual(positioned[1].column, 1)
        XCTAssertEqual(positioned[1].totalColumns, 2)
        XCTAssertEqual(positioned[0].widthFraction, 0.5)
        XCTAssertEqual(positioned[1].widthFraction, 0.5)
        XCTAssertEqual(positioned[1].leftFraction, 0.5)
    }

    func testConsecutiveEventsDoNotSplit() {
        let base = Date()
        let event1 = CalendarEvent(
            id: "1",
            calendarId: "cal1",
            summary: "Meeting 1",
            start: base,
            end: base.addingTimeInterval(3600)
        )
        let event2 = CalendarEvent(
            id: "2",
            calendarId: "cal1",
            summary: "Meeting 2",
            start: base.addingTimeInterval(3600), // starts exactly when event1 ends
            end: base.addingTimeInterval(7200)
        )

        let positioned = EventLayoutAlgorithm.layoutEvents([event1, event2])
        XCTAssertEqual(positioned.count, 2)
        XCTAssertEqual(positioned[0].column, 0)
        XCTAssertEqual(positioned[0].totalColumns, 1)
        XCTAssertEqual(positioned[1].column, 0)
        XCTAssertEqual(positioned[1].totalColumns, 1)
    }
}
