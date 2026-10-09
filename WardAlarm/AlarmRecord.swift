import Foundation

struct AlarmRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    let fireDate: Date
    let isTest: Bool
    let continuationID: UUID?

    var systemIDs: [UUID] {
        guard let continuationID, continuationID != id else { return [id] }
        return [id, continuationID]
    }

    var continuationDate: Date { fireDate.addingTimeInterval(60) }

    init(id: UUID = UUID(), createdAt: Date = Date(), fireDate: Date, isTest: Bool = false, continuationID: UUID? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.fireDate = fireDate
        self.isTest = isTest
        self.continuationID = continuationID
    }
}

enum AlarmTimeError: LocalizedError {
    case invalidDuration
    case invalidClockTime

    var errorDescription: String? {
        switch self {
        case .invalidDuration:
            return "Kies een duur van minimaal 1 minuut en maximaal 7 dagen."
        case .invalidClockTime:
            return "Dit tijdstip kon niet worden ingesteld. Kies een ander tijdstip."
        }
    }
}

enum AlarmTime {
    static let defaultDuration: TimeInterval = 3 * 60 * 60
    static let testDuration: TimeInterval = 10
    static let maximumDuration: TimeInterval = 7 * 24 * 60 * 60

    static func after(_ seconds: TimeInterval, now: Date = Date()) throws -> Date {
        guard seconds.isFinite, seconds >= 60, seconds <= maximumDuration else {
            throw AlarmTimeError.invalidDuration
        }
        return now.addingTimeInterval(seconds)
    }

    static func nextClockTime(hour: Int, minute: Int, now: Date = Date(), calendar: Calendar = .current) throws -> Date {
        guard (0...23).contains(hour), (0...59).contains(minute) else {
            throw AlarmTimeError.invalidClockTime
        }
        let components = DateComponents(hour: hour, minute: minute, second: 0)
        // Consider both occurrences when the clocks move back.
        let candidates = [Calendar.RepeatedTimePolicy.first, .last].compactMap {
            calendar.nextDate(
                after: now,
                matching: components,
                matchingPolicy: .nextTimePreservingSmallerComponents,
                repeatedTimePolicy: $0,
                direction: .forward
            )
        }.filter { $0 > now }
        guard let next = candidates.min() else { throw AlarmTimeError.invalidClockTime }
        return next
    }
}

enum AlarmDateText {
    static func time(_ date: Date, includeSeconds: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_BE")
        formatter.dateFormat = includeSeconds ? "HH:mm:ss" : "HH:mm"
        return formatter.string(from: date)
    }

    static func day(_ date: Date, now: Date = Date()) -> String {
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: now) { return "Vandaag" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(date, inSameDayAs: tomorrow) { return "Morgen" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_BE")
        formatter.dateFormat = "EEE d MMM"
        return formatter.string(from: date)
    }

    static func target(_ alarm: AlarmRecord) -> String {
        "\(day(alarm.fireDate).lowercased()) om \(time(alarm.fireDate, includeSeconds: alarm.isTest))"
    }
}

// The sound transition uses two iOS alarms, but is one logical alarm in the UI.
// Keep its original time and identity when only the full-volume phase remains.
struct SystemAlarmEntry {
    let id: UUID
    let fireDate: Date?
    let isAlerting: Bool
}

struct ReconciledAlarms {
    let records: [AlarmRecord]
    let ringingIDs: Set<UUID>
}

enum AlarmReconciliation {
    static func reconcile(saved: [AlarmRecord], system: [SystemAlarmEntry]) -> ReconciledAlarms {
        let currentIDs = Set(system.map(\.id))
        let alertingIDs = Set(system.filter(\.isAlerting).map(\.id))
        var records: [AlarmRecord] = []
        var ringing = Set<UUID>()
        var handledIDs = Set<UUID>()
        var seenRecords = Set<UUID>()

        for record in saved where seenRecords.insert(record.id).inserted {
            let ids = Set(record.systemIDs)
            handledIDs.formUnion(ids)
            guard !ids.isDisjoint(with: currentIDs) else { continue }
            records.append(record)
            if !ids.isDisjoint(with: alertingIDs) { ringing.insert(record.id) }
        }

        // Preserve the existing recovery behavior for unrelated/legacy alarms.
        for entry in system where !handledIDs.contains(entry.id) {
            guard let date = entry.fireDate, seenRecords.insert(entry.id).inserted else { continue }
            records.append(AlarmRecord(id: entry.id, fireDate: date))
            if entry.isAlerting { ringing.insert(entry.id) }
        }
        records.sort { $0.fireDate < $1.fireDate }
        return ReconciledAlarms(records: records, ringingIDs: ringing)
    }
}

enum AlarmAppearancePolicy {
    static func isDim(brightness: Double, wasDim: Bool) -> Bool {
        guard brightness.isFinite else { return wasDim }
        // Separate enter/leave thresholds prevent flicker near the boundary.
        if brightness < 0.25 { return true }
        if brightness > 0.40 { return false }
        return wasDim
    }
}
