import XCTest
@testable import WardAlarm

final class AlarmTimeTests: XCTestCase {
    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    private var belgianCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Brussels")!
        return calendar
    }

    func testDefaultIsExactlyThreeHoursAcrossDaylightSavingChange() throws {
        let now = date("2026-10-25T00:30:00Z")
        XCTAssertEqual(try AlarmTime.after(AlarmTime.defaultDuration, now: now), date("2026-10-25T03:30:00Z"))
    }

    func testClockTimeUsesTodayOrTomorrow() throws {
        let now = date("2026-10-09T12:00:00Z") // 14:00 in Belgium.
        XCTAssertEqual(try AlarmTime.nextClockTime(hour: 15, minute: 20, now: now, calendar: belgianCalendar), date("2026-10-09T13:20:00Z"))
        XCTAssertEqual(try AlarmTime.nextClockTime(hour: 13, minute: 20, now: now, calendar: belgianCalendar), date("2026-10-10T11:20:00Z"))
    }

    func testExactCurrentMinuteUsesNextOccurrence() throws {
        XCTAssertEqual(try AlarmTime.nextClockTime(hour: 14, minute: 0, now: date("2026-10-09T12:00:00Z"), calendar: belgianCalendar), date("2026-10-10T12:00:00Z"))
    }

    func testMissingSpringTimePreservesMinutes() throws {
        XCTAssertEqual(try AlarmTime.nextClockTime(hour: 2, minute: 30, now: date("2027-03-28T00:00:00Z"), calendar: belgianCalendar), date("2027-03-28T01:30:00Z"))
    }

    func testAutumnRepeatChoosesFirstFutureOccurrence() throws {
        XCTAssertEqual(try AlarmTime.nextClockTime(hour: 2, minute: 30, now: date("2026-10-25T00:00:00Z"), calendar: belgianCalendar), date("2026-10-25T00:30:00Z"))
        XCTAssertEqual(try AlarmTime.nextClockTime(hour: 2, minute: 30, now: date("2026-10-25T00:45:00Z"), calendar: belgianCalendar), date("2026-10-25T01:30:00Z"))
    }

    func testInvalidDurationsAndClockTimesAreRejected() {
        for duration in [0.0, 59.0, .infinity, .nan, AlarmTime.maximumDuration + 1] {
            XCTAssertThrowsError(try AlarmTime.after(duration))
        }
        XCTAssertThrowsError(try AlarmTime.nextClockTime(hour: 24, minute: 0))
        XCTAssertThrowsError(try AlarmTime.nextClockTime(hour: 12, minute: 60))
    }

    func testMultipleAlarmsAndTestMarkerSurvivePersistence() throws {
        let first = AlarmRecord(fireDate: date("2026-10-09T15:00:00Z"))
        let second = AlarmRecord(fireDate: date("2026-10-09T16:00:00Z"), isTest: true)
        XCTAssertNotEqual(first.id, second.id)
        let saved = try JSONEncoder().encode([first, second])
        XCTAssertEqual(try JSONDecoder().decode([AlarmRecord].self, from: saved), [first, second])
    }
}
