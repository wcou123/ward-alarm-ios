import ActivityKit
import AlarmKit
import Foundation
import UIKit

@MainActor
enum NextAlarmLiveActivity {
    private struct Update {
        let alarm: AlarmRecord?
        let enabled: Bool
        let allowStart: Bool
        let report: ((String?) -> Void)?
    }

    private static var pending: Update?
    private static var worker: Task<Void, Never>?

    static func synchronize(alarm: AlarmRecord?, enabled: Bool,
                            allowStart: Bool = false, report: ((String?) -> Void)? = nil) {
        // Coalesce updates, and serialize ActivityKit calls across suspension
        // points so a slow old update cannot overwrite a newer alarm selection.
        pending = Update(alarm: alarm, enabled: enabled,
                         allowStart: allowStart || UIApplication.shared.applicationState == .active || pending?.allowStart == true,
                         report: report)
        guard worker == nil else { return }
        worker = Task {
            while let update = pending {
                pending = nil
                let message = await apply(update)
                if pending == nil { update.report?(message) }
            }
            worker = nil
        }
    }

    static func finishPendingUpdates() async {
        await worker?.value
    }

    static func synchronizeFromSystem(allowStart: Bool) throws {
        let defaults = UserDefaults.standard
        let data = defaults.data(forKey: AlarmPersistence.recordsKey)
        let saved = data.flatMap { try? JSONDecoder().decode([AlarmRecord].self, from: $0) } ?? []
        let entries = try AlarmManager.shared.alarms.map { alarm -> SystemAlarmEntry in
            let date: Date?
            if let schedule = alarm.schedule, case .fixed(let fixed) = schedule { date = fixed }
            else { date = nil }
            return SystemAlarmEntry(id: alarm.id, fireDate: date, isAlerting: alarm.state == .alerting)
        }
        let result = AlarmReconciliation.reconcile(saved: saved, system: entries)
        if let encoded = try? JSONEncoder().encode(result.records) {
            defaults.set(encoded, forKey: AlarmPersistence.recordsKey)
        }
        synchronize(alarm: NextAlarmSelection.next(in: result.records, ringingIDs: result.ringingIDs),
                    enabled: AlarmPersistence.showsNextAlarm(in: defaults), allowStart: allowStart)
    }

    private static func apply(_ update: Update) async -> String? {
        let activities = Activity<NextAlarmAttributes>.activities
        guard update.enabled, let alarm = update.alarm, alarm.fireDate > Date() else {
            for activity in activities { await activity.end(nil, dismissalPolicy: .immediate) }
            return nil
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            for activity in activities { await activity.end(nil, dismissalPolicy: .immediate) }
            return "Sta live activiteiten toe via Instellingen → Apps → BeutAlarm → Live activiteiten."
        }

        let primary = activities.first { $0.activityState == .active || $0.activityState == .stale }
        // Maintain one next-alarm display, independently of the two sound phases.
        for activity in activities where activity.id != primary?.id {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        let state = NextAlarmAttributes.ContentState(alarmID: alarm.id,
                                                     fireDate: alarm.fireDate, isTest: alarm.isTest)
        let content = ActivityContent(state: state, staleDate: alarm.fireDate)
        if let primary {
            if primary.content.state != state { await primary.update(content) }
            return nil
        }
        guard update.allowStart else {
            return "Open BeutAlarm om het eerstvolgende alarm op je toegangsscherm te tonen."
        }
        do {
            _ = try Activity<NextAlarmAttributes>.request(attributes: NextAlarmAttributes(),
                                                         content: content, pushType: nil)
            return nil
        } catch {
            return "De weergave op het toegangsscherm kon niet starten. Je alarm blijft ingesteld. Open BeutAlarm opnieuw."
        }
    }
}
