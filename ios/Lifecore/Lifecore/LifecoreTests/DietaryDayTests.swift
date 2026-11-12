import XCTest
@testable import Lifecore

final class DietaryDayTests: XCTestCase {

    private var budapestCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Budapest")!
        return cal
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        second: Int,
        in calendar: Calendar
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        guard let date = calendar.date(from: components) else {
            fatalError("Invalid test date components: \(components)")
        }
        return date
    }

    func testTimezoneBudapestBoundaryJustBeforeAndAt4AM() {
        let cal = budapestCalendar

        // 2026-11-12 03:59:59 -> belongs to 2026-11-11
        let justBefore4 = makeDate(year: 2026, month: 11, day: 12, hour: 3, minute: 59, second: 59, in: cal)
        let dayBefore4 = DietaryDay.containing(justBefore4, calendar: cal)

        let expectedStartPrev = makeDate(year: 2026, month: 11, day: 11, hour: 4, minute: 0, second: 0, in: cal)
        let expectedEndPrev = makeDate(year: 2026, month: 11, day: 12, hour: 4, minute: 0, second: 0, in: cal)

        XCTAssertEqual(dayBefore4.key, "2026-11-11")
        XCTAssertEqual(dayBefore4.interval.start, expectedStartPrev)
        XCTAssertEqual(dayBefore4.interval.end, expectedEndPrev)
        XCTAssertEqual(dayBefore4.timeZoneID, "Europe/Budapest")

        // 2026-11-12 04:00:00 -> belongs to 2026-11-12
        let exactly4 = makeDate(year: 2026, month: 11, day: 12, hour: 4, minute: 0, second: 0, in: cal)
        let dayAt4 = DietaryDay.containing(exactly4, calendar: cal)

        let expectedStartCurr = makeDate(year: 2026, month: 11, day: 12, hour: 4, minute: 0, second: 0, in: cal)
        let expectedEndCurr = makeDate(year: 2026, month: 11, day: 13, hour: 4, minute: 0, second: 0, in: cal)

        XCTAssertEqual(dayAt4.key, "2026-11-12")
        XCTAssertEqual(dayAt4.interval.start, expectedStartCurr)
        XCTAssertEqual(dayAt4.interval.end, expectedEndCurr)
        XCTAssertEqual(dayAt4.timeZoneID, "Europe/Budapest")

        // Zero gap and zero overlap between adjacent days
        XCTAssertEqual(dayBefore4.interval.end, dayAt4.interval.start)
    }

    func testSpringForwardTransitionProduces23HourInterval() {
        let cal = budapestCalendar

        // In Europe/Budapest, DST begins Sunday, March 29, 2026 (clocks jump 02:00 -> 03:00)
        // The dietary day starting 2026-03-28 04:00 CET ends 2026-03-29 04:00 CEST.
        // It loses one hour during the night, so duration is 23 hours (82,800 seconds).
        let afternoonMarch28 = makeDate(year: 2026, month: 3, day: 28, hour: 14, minute: 0, second: 0, in: cal)
        let springDay = DietaryDay.containing(afternoonMarch28, calendar: cal)

        let expectedStart = makeDate(year: 2026, month: 3, day: 28, hour: 4, minute: 0, second: 0, in: cal)
        let expectedEnd = makeDate(year: 2026, month: 3, day: 29, hour: 4, minute: 0, second: 0, in: cal)

        XCTAssertEqual(springDay.key, "2026-03-28")
        XCTAssertEqual(springDay.interval.start, expectedStart)
        XCTAssertEqual(springDay.interval.end, expectedEnd)
        XCTAssertEqual(springDay.interval.duration, 23 * 3600, accuracy: 0.001, "Spring-forward interval must be 23 hours")

        // Subsequent day starting 2026-03-29 04:00 CEST
        let morningMarch29 = makeDate(year: 2026, month: 3, day: 29, hour: 8, minute: 0, second: 0, in: cal)
        let nextDay = DietaryDay.containing(morningMarch29, calendar: cal)

        XCTAssertEqual(nextDay.key, "2026-03-29")
        XCTAssertEqual(springDay.interval.end, nextDay.interval.start, "Adjacent boundaries must align with zero gap/overlap")
    }

    func testFallBackTransitionProduces25HourInterval() {
        let cal = budapestCalendar

        // In Europe/Budapest, DST ends Sunday, October 25, 2026 (clocks jump 03:00 -> 02:00)
        // The dietary day starting 2026-10-24 04:00 CEST ends 2026-10-25 04:00 CET.
        // It gains one hour during the night, so duration is 25 hours (90,000 seconds).
        let afternoonOct24 = makeDate(year: 2026, month: 10, day: 24, hour: 15, minute: 0, second: 0, in: cal)
        let fallDay = DietaryDay.containing(afternoonOct24, calendar: cal)

        let expectedStart = makeDate(year: 2026, month: 10, day: 24, hour: 4, minute: 0, second: 0, in: cal)
        let expectedEnd = makeDate(year: 2026, month: 10, day: 25, hour: 4, minute: 0, second: 0, in: cal)

        XCTAssertEqual(fallDay.key, "2026-10-24")
        XCTAssertEqual(fallDay.interval.start, expectedStart)
        XCTAssertEqual(fallDay.interval.end, expectedEnd)
        XCTAssertEqual(fallDay.interval.duration, 25 * 3600, accuracy: 0.001, "Fall-back interval must be 25 hours")

        // Subsequent day starting 2026-10-25 04:00 CET
        let morningOct25 = makeDate(year: 2026, month: 10, day: 25, hour: 6, minute: 0, second: 0, in: cal)
        let nextDay = DietaryDay.containing(morningOct25, calendar: cal)

        XCTAssertEqual(nextDay.key, "2026-10-25")
        XCTAssertEqual(fallDay.interval.end, nextDay.interval.start, "Adjacent boundaries must align with zero gap/overlap")
    }

    func testHalfOpenIntervalMembership() {
        let cal = budapestCalendar
        let date = makeDate(year: 2026, month: 6, day: 15, hour: 12, minute: 0, second: 0, in: cal)
        let day = DietaryDay.containing(date, calendar: cal)

        // Exact start is INCLUDED
        XCTAssertTrue(day.contains(day.interval.start))

        // 1 millisecond before start is EXCLUDED
        XCTAssertFalse(day.contains(day.interval.start.addingTimeInterval(-0.001)))

        // Exact end is EXCLUDED
        XCTAssertFalse(day.contains(day.interval.end))

        // 1 millisecond before end is INCLUDED
        XCTAssertTrue(day.contains(day.interval.end.addingTimeInterval(-0.001)))
    }

    func testYearBoundaryShift() {
        let cal = budapestCalendar

        // 2026-01-01 02:30:00 -> before 04:00, belongs to 2025-12-31
        let newYearEarly = makeDate(year: 2026, month: 1, day: 1, hour: 2, minute: 30, second: 0, in: cal)
        let day = DietaryDay.containing(newYearEarly, calendar: cal)

        XCTAssertEqual(day.key, "2025-12-31")

        let expectedStart = makeDate(year: 2025, month: 12, day: 31, hour: 4, minute: 0, second: 0, in: cal)
        let expectedEnd = makeDate(year: 2026, month: 1, day: 1, hour: 4, minute: 0, second: 0, in: cal)

        XCTAssertEqual(day.interval.start, expectedStart)
        XCTAssertEqual(day.interval.end, expectedEnd)
    }

    func testMonthBoundaryShift() {
        let cal = budapestCalendar

        // 2026-03-01 01:15:00 -> before 04:00, belongs to 2026-02-28
        let marchFirstEarly = makeDate(year: 2026, month: 3, day: 1, hour: 1, minute: 15, second: 0, in: cal)
        let day = DietaryDay.containing(marchFirstEarly, calendar: cal)

        XCTAssertEqual(day.key, "2026-02-28")

        let expectedStart = makeDate(year: 2026, month: 2, day: 28, hour: 4, minute: 0, second: 0, in: cal)
        let expectedEnd = makeDate(year: 2026, month: 3, day: 1, hour: 4, minute: 0, second: 0, in: cal)

        XCTAssertEqual(day.interval.start, expectedStart)
        XCTAssertEqual(day.interval.end, expectedEnd)
    }

    func testHashableAndEquatable() {
        let cal = budapestCalendar
        let d1 = makeDate(year: 2026, month: 7, day: 10, hour: 8, minute: 0, second: 0, in: cal)
        let d2 = makeDate(year: 2026, month: 7, day: 10, hour: 22, minute: 0, second: 0, in: cal)

        let day1 = DietaryDay.containing(d1, calendar: cal)
        let day2 = DietaryDay.containing(d2, calendar: cal)

        XCTAssertEqual(day1, day2)
        XCTAssertEqual(day1.hashValue, day2.hashValue)
    }
}
