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


final class AlarmPhaseTests: XCTestCase {
    func testLegacyRecordsWithoutContinuationRemainReadable() throws {
        let legacy = Data("""
        {"id":"00000000-0000-0000-0000-000000000001","createdAt":100,"fireDate":200,"isTest":false}
        """.utf8)
        let record = try JSONDecoder().decode(AlarmRecord.self, from: legacy)
        XCTAssertNil(record.continuationID)
        XCTAssertEqual(record.systemIDs, [record.id])
        XCTAssertEqual(record.fireDate, Date(timeIntervalSinceReferenceDate: 200))
    }

    func testBothSoundPhasesAreOneVisibleAlarmAtItsOriginalTime() {
        let record = AlarmRecord(fireDate: Date(timeIntervalSinceReferenceDate: 1000), continuationID: UUID())
        let result = AlarmReconciliation.reconcile(saved: [record], system: [
            SystemAlarmEntry(id: record.id, fireDate: record.fireDate, isAlerting: false),
            SystemAlarmEntry(id: record.continuationID!, fireDate: record.continuationDate, isAlerting: true)
        ])
        XCTAssertEqual(result.records, [record])
        XCTAssertEqual(result.records[0].fireDate, record.fireDate)
        XCTAssertEqual(result.ringingIDs, [record.id])
        XCTAssertEqual(record.continuationDate.timeIntervalSince(record.fireDate), 60)
    }

    func testLoudPhaseSurvivesAfterCrescendoIsRetired() {
        let record = AlarmRecord(fireDate: Date(timeIntervalSinceReferenceDate: 1000), continuationID: UUID())
        let result = AlarmReconciliation.reconcile(saved: [record], system: [
            SystemAlarmEntry(id: record.continuationID!, fireDate: record.continuationDate, isAlerting: true)
        ])
        XCTAssertEqual(result.records, [record])
        XCTAssertEqual(result.ringingIDs, [record.id])
    }

    func testIndependentAlarmRemainsBesideTheGroupedSoundPhases() {
        let first = AlarmRecord(fireDate: Date(timeIntervalSinceReferenceDate: 1000), continuationID: UUID())
        let second = AlarmRecord(fireDate: Date(timeIntervalSinceReferenceDate: 2000), continuationID: UUID())
        let result = AlarmReconciliation.reconcile(saved: [first, second], system: [
            SystemAlarmEntry(id: first.id, fireDate: first.fireDate, isAlerting: true),
            SystemAlarmEntry(id: first.continuationID!, fireDate: first.continuationDate, isAlerting: false),
            SystemAlarmEntry(id: second.id, fireDate: second.fireDate, isAlerting: false),
            SystemAlarmEntry(id: second.continuationID!, fireDate: second.continuationDate, isAlerting: false)
        ])
        XCTAssertEqual(result.records, [first, second])
        XCTAssertEqual(result.ringingIDs, [first.id])
    }

    func testContinuationIdentitySurvivesPersistence() throws {
        let record = AlarmRecord(fireDate: Date(), isTest: true, continuationID: UUID())
        let decoded = try JSONDecoder().decode(AlarmRecord.self, from: JSONEncoder().encode(record))
        XCTAssertEqual(decoded, record)
        XCTAssertEqual(decoded.systemIDs, record.systemIDs)
    }

    @MainActor
    func testStoppingBeforeMinuteOneAlsoCancelsTheFutureLoudPhase() throws {
        let record = AlarmRecord(fireDate: Date(), continuationID: UUID())
        let other = UUID()
        let client = FakeAlarmCanceler(ids: Set(record.systemIDs + [other]))
        try AlarmCancellation.cancelAll(record.systemIDs, using: client)
        XCTAssertEqual(client.ids, [other])
        XCTAssertEqual(client.calls, record.systemIDs)
    }

    @MainActor
    func testSystemStopAlreadyRemovingFirstPhaseDoesNotLeaveLoudPhase() throws {
        let record = AlarmRecord(fireDate: Date(), continuationID: UUID())
        let client = FakeAlarmCanceler(ids: [record.continuationID!])
        try AlarmCancellation.cancelAll(record.systemIDs, using: client)
        XCTAssertTrue(client.ids.isEmpty)
        XCTAssertEqual(client.calls, [record.continuationID!])
    }

    @MainActor
    func testFailureInOnePhaseStillAttemptsCancellationOfTheOther() {
        let record = AlarmRecord(fireDate: Date(), continuationID: UUID())
        let client = FakeAlarmCanceler(ids: Set(record.systemIDs))
        client.failures = [record.id]
        XCTAssertThrowsError(try AlarmCancellation.cancelAll(record.systemIDs, using: client))
        XCTAssertEqual(client.calls, record.systemIDs)
        XCTAssertEqual(client.ids, [record.id])
    }

    @MainActor
    func testDisappearingAlarmRaceStillCancelsItsRemainingPhase() throws {
        let record = AlarmRecord(fireDate: Date(), continuationID: UUID())
        let client = FakeAlarmCanceler(ids: Set(record.systemIDs))
        client.disappearDuringCancel = [record.id]
        try AlarmCancellation.cancelAll(record.systemIDs, using: client)
        XCTAssertTrue(client.ids.isEmpty)
        XCTAssertEqual(client.calls, record.systemIDs)
    }
}

@MainActor
private final class FakeAlarmCanceler: AlarmCanceling {
    enum Failure: Error { case refused }
    var ids: Set<UUID>
    var calls: [UUID] = []
    var failures = Set<UUID>()
    var disappearDuringCancel = Set<UUID>()

    init(ids: Set<UUID>) { self.ids = ids }
    func currentIDs() throws -> Set<UUID> { ids }
    func cancel(id: UUID) throws {
        calls.append(id)
        if disappearDuringCancel.contains(id) {
            ids.remove(id)
            throw Failure.refused
        }
        if failures.contains(id) { throw Failure.refused }
        ids.remove(id)
    }
}

final class AlarmAppearanceTests: XCTestCase {
    func testDimScreenRequestsDarkContentAndBrightScreenReleasesIt() {
        XCTAssertTrue(AlarmAppearancePolicy.isDim(brightness: 0.1, wasDim: false))
        XCTAssertFalse(AlarmAppearancePolicy.isDim(brightness: 0.8, wasDim: true))
    }

    func testBoundaryDoesNotFlickerOrReactToInvalidBrightness() {
        XCTAssertTrue(AlarmAppearancePolicy.isDim(brightness: 0.3, wasDim: true))
        XCTAssertFalse(AlarmAppearancePolicy.isDim(brightness: 0.3, wasDim: false))
        XCTAssertTrue(AlarmAppearancePolicy.isDim(brightness: .nan, wasDim: true))
        XCTAssertFalse(AlarmAppearancePolicy.isDim(brightness: .infinity, wasDim: false))
    }
}


final class NextAlarmSelectionTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testEmptyOverviewHasNoNextAlarm() {
        XCTAssertNil(NextAlarmSelection.next(in: [], now: now))
    }

    func testSelectsEarliestTimeRegardlessOfInputOrder() {
        let later = AlarmRecord(fireDate: now.addingTimeInterval(10_800))
        let first = AlarmRecord(fireDate: now.addingTimeInterval(900))
        XCTAssertEqual(NextAlarmSelection.next(in: [later, first], now: now), first)
    }

    func testRingingAndPastTimesAreNeverAdvertisedAsUpcoming() {
        let past = AlarmRecord(fireDate: now.addingTimeInterval(-10))
        let ringing = AlarmRecord(fireDate: now.addingTimeInterval(1))
        let next = AlarmRecord(fireDate: now.addingTimeInterval(60))
        XCTAssertEqual(NextAlarmSelection.next(in: [past, ringing, next], ringingIDs: [ringing.id], now: now), next)
        XCTAssertNil(NextAlarmSelection.next(in: [AlarmRecord(fireDate: now)], now: now))
    }

    func testLoudContinuationDoesNotBecomeAnExtraUpcomingAlarm() {
        let sounding = AlarmRecord(fireDate: now.addingTimeInterval(-30), continuationID: UUID())
        let next = AlarmRecord(fireDate: now.addingTimeInterval(900))
        let reconciled = AlarmReconciliation.reconcile(saved: [sounding, next], system: [
            SystemAlarmEntry(id: sounding.continuationID!, fireDate: sounding.continuationDate, isAlerting: false),
            SystemAlarmEntry(id: next.id, fireDate: next.fireDate, isAlerting: false)
        ])
        XCTAssertEqual(NextAlarmSelection.next(in: reconciled.records, now: now), next)
    }

    func testAddingEarlierAndRemovingItRestoresTheOtherAlarm() {
        let original = AlarmRecord(fireDate: now.addingTimeInterval(10_800))
        let added = AlarmRecord(fireDate: now.addingTimeInterval(900))
        XCTAssertEqual(NextAlarmSelection.next(in: [original, added], now: now), added)
        let reconciled = AlarmReconciliation.reconcile(saved: [original, added], system: [
            SystemAlarmEntry(id: original.id, fireDate: original.fireDate, isAlerting: false)
        ])
        XCTAssertEqual(NextAlarmSelection.next(in: reconciled.records, now: now), original)
    }
}
