import Foundation

struct AlarmRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    let fireDate: Date
    let isTest: Bool

    init(id: UUID = UUID(), createdAt: Date = Date(), fireDate: Date, isTest: Bool = false) {
        self.id = id
        self.createdAt = createdAt
        self.fireDate = fireDate
        self.isTest = isTest
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
