import AlarmKit
import AppIntents
import Foundation

@MainActor
protocol AlarmCanceling {
    func currentIDs() throws -> Set<UUID>
    func cancel(id: UUID) throws
}

@MainActor
struct SystemAlarmCanceler: AlarmCanceling {
    func currentIDs() throws -> Set<UUID> {
        Set(try AlarmManager.shared.alarms.map(\.id))
    }

    func cancel(id: UUID) throws {
        try AlarmManager.shared.cancel(id: id)
    }
}

enum AlarmCancellation {
    @MainActor
    static func cancelAll(_ ids: [UUID], using client: any AlarmCanceling) throws {
        let existing = try client.currentIDs()
        var seen = Set<UUID>()
        var firstError: Error?
        for id in ids where existing.contains(id) && seen.insert(id).inserted {
            do { try client.cancel(id: id) }
            catch {
                // Still cancel the other phase if one call fails. A phase may
                // also have disappeared between the snapshot and cancellation.
                if let remaining = try? client.currentIDs(), !remaining.contains(id) { continue }
                if firstError == nil { firstError = error }
            }
        }
        if let firstError { throw firstError }
    }
}

struct StopBeutAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop BeutAlarm"
    static var openAppWhenRun = false
    static var isDiscoverable = false

    @Parameter(title: "Alarm") var alarmID: String
    @Parameter(title: "Luide fase") var continuationID: String

    init() {}

    init(alarmID: UUID, continuationID: UUID) {
        self.alarmID = alarmID.uuidString
        self.continuationID = continuationID.uuidString
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let ids = [alarmID, continuationID].compactMap(UUID.init(uuidString:))
        try AlarmCancellation.cancelAll(ids, using: SystemAlarmCanceler())
        return .result()
    }
}
