import AlarmKit
import Combine
import Foundation
import SwiftUI

struct WardAlarmMetadata: AlarmMetadata {}

enum AlarmDialog: Identifiable {
    case remove(AlarmRecord)
    case error(String)

    var id: String {
        switch self {
        case .remove(let alarm): return "remove-\(alarm.id)"
        case .error(let message): return "error-\(message)"
        }
    }
}

@MainActor
final class AlarmStore: ObservableObject {
    @Published private(set) var alarms: [AlarmRecord]
    @Published private(set) var ringingIDs = Set<UUID>()
    @Published private(set) var authorization = AlarmManager.shared.authorizationState
    @Published private(set) var isBusy = false
    @Published private(set) var didReadSystemAlarms = false
    @Published private(set) var statusMessage: String?
    @Published var dialog: AlarmDialog?

    let soundPreview = SoundPreview()
    private let defaults: UserDefaults
    private static let storageKey = "ward.alarm.records.v1"
    private var alarmUpdatesTask: Task<Void, Never>?
    private var authorizationTask: Task<Void, Never>?
    private var pendingRecords: [UUID: AlarmRecord] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode([AlarmRecord].self, from: data) {
            alarms = saved.sorted { $0.fireDate < $1.fireDate }
        } else {
            alarms = []
        }
    }

    func startObserving() {
        refreshFromSystem()
        guard alarmUpdatesTask == nil else { return }
        alarmUpdatesTask = Task { [weak self] in
            for await snapshot in AlarmManager.shared.alarmUpdates {
                guard let self else { return }
                if self.authorization == .authorized { self.apply(snapshot) }
            }
        }
        authorizationTask = Task { [weak self] in
            for await state in AlarmManager.shared.authorizationUpdates {
                guard let self else { return }
                self.authorization = state
                self.didReadSystemAlarms = false
                if state == .authorized { self.refreshFromSystem() }
            }
        }
    }

    func refreshFromSystem() {
        authorization = AlarmManager.shared.authorizationState
        guard authorization == .authorized else {
            didReadSystemAlarms = false
            return
        }
        do {
            apply(try AlarmManager.shared.alarms)
        } catch {
            didReadSystemAlarms = false
            statusMessage = "De alarmen konden niet bij je iPhone worden gecontroleerd. Open de app opnieuw."
        }
    }

    func authorize() async -> Bool {
        do {
            authorization = try await AlarmManager.shared.requestAuthorization()
            if authorization == .authorized {
                refreshFromSystem()
                return true
            }
            dialog = .error("Geef BeutAlarm toestemming via Instellingen → Apps → BeutAlarm → Alarmen. Zonder toestemming wordt er geen alarm ingesteld.")
        } catch {
            dialog = .error("Toestemming vragen is mislukt: \(error.localizedDescription)")
        }
        return false
    }

    func add(after seconds: TimeInterval) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        guard await authorize() else { return }
        do { try await schedule(fireDate: AlarmTime.after(seconds)) }
        catch { dialog = .error(error.localizedDescription) }
    }

    func add(at clockTime: Date) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        guard await authorize() else { return }
        do {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: clockTime)
            let date = try AlarmTime.nextClockTime(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
            try await schedule(fireDate: date)
        } catch { dialog = .error(error.localizedDescription) }
    }

    func testLockedScreenAlarm() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        guard await authorize() else { return }
        do {
            try await schedule(fireDate: Date().addingTimeInterval(AlarmTime.testDuration), isTest: true)
            statusMessage = "Testalarm ingesteld. Vergrendel nu je iPhone met de zijknop."
        } catch { dialog = .error(error.localizedDescription) }
    }

    func requestRemoval(of alarm: AlarmRecord) {
        guard !isBusy else { return }
        dialog = .remove(alarm)
    }

    func removeConfirmed(_ alarm: AlarmRecord) {
        guard !isBusy else { return }
        do {
            // Never remove the saved record before iOS confirms cancellation.
            try AlarmCancellation.cancelAll(alarm.systemIDs, using: SystemAlarmCanceler())
            alarms.removeAll { $0.id == alarm.id }
            ringingIDs.remove(alarm.id)
            persist()
            statusMessage = "Alarm verwijderd."
            refreshFromSystem()
        } catch {
            // A one-shot alarm might have stopped since the confirmation opened.
            if let current = try? AlarmManager.shared.alarms,
               !current.contains(where: { alarm.systemIDs.contains($0.id) }) {
                apply(current)
                statusMessage = "Dit alarm is al gestopt."
            } else {
                dialog = .error("Het alarm is niet verwijderd: \(error.localizedDescription)")
            }
        }
    }

    func stopRinging(_ alarm: AlarmRecord) {
        do {
            try AlarmCancellation.cancelAll(alarm.systemIDs, using: SystemAlarmCanceler())
            refreshFromSystem()
        } catch { dialog = .error("Het alarm kon niet worden gestopt: \(error.localizedDescription)") }
    }

    private func schedule(fireDate: Date, isTest: Bool = false) async throws {
        soundPreview.stop()
        let continuationID = UUID()
        let record = AlarmRecord(fireDate: fireDate, isTest: isTest, continuationID: continuationID)
        pendingRecords[record.id] = record
        defer { pendingRecords.removeValue(forKey: record.id) }

        let presentation = AlarmPresentation.Alert(
            title: isTest ? "Testalarm" : "BeutAlarm",
            stopButton: AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.circle")
        )
        let attributes = AlarmAttributes<WardAlarmMetadata>(
            presentation: AlarmPresentation(alert: presentation),
            metadata: WardAlarmMetadata(),
            tintColor: Color(red: 0.12, green: 0.24, blue: 0.40)
        )
        let stopIntent = StopBeutAlarmIntent(alarmID: record.id, continuationID: continuationID)
        let first = AlarmManager.AlarmConfiguration<WardAlarmMetadata>.alarm(
            schedule: .fixed(record.fireDate), attributes: attributes,
            stopIntent: stopIntent, sound: .named("crescendo-alarm.wav")
        )
        let sustained = AlarmManager.AlarmConfiguration<WardAlarmMetadata>.alarm(
            schedule: .fixed(record.continuationDate), attributes: attributes,
            stopIntent: stopIntent, sound: .named("windows-alarm.wav")
        )

        do {
            _ = try await AlarmManager.shared.schedule(id: record.id, configuration: first)
            _ = try await AlarmManager.shared.schedule(id: continuationID, configuration: sustained)
        } catch {
            let schedulingError = error
            do { try AlarmCancellation.cancelAll(record.systemIDs, using: SystemAlarmCanceler()) }
            catch {
                // Preserve and expose any phase which could not be rolled back.
                alarms.removeAll { $0.id == record.id }
                alarms.append(record)
                persist()
                refreshFromSystem()
                throw NSError(domain: "WardAlarm", code: 3, userInfo: [NSLocalizedDescriptionKey:
                    "Het volledige alarm kon niet worden ingesteld en een overgebleven deel kon niet worden verwijderd. Controleer het overzicht en verwijder dit alarm. \(error.localizedDescription)"])
            }
            refreshFromSystem()
            throw schedulingError
        }

        alarms.removeAll { $0.id == record.id }
        alarms.append(record)
        alarms.sort { $0.fireDate < $1.fireDate }
        persist()
        statusMessage = "Alarm ingesteld \(AlarmDateText.target(record))."
        refreshFromSystem()
    }

    private func apply(_ snapshot: [Alarm]) {
        // Pending records prevent an update during either schedule call from
        // temporarily exposing the internal loud phase as an extra user alarm.
        let saved = Array(pendingRecords.values) + alarms
        let entries = snapshot.map { alarm -> SystemAlarmEntry in
            let date: Date?
            if let schedule = alarm.schedule, case .fixed(let fixed) = schedule { date = fixed }
            else { date = nil }
            return SystemAlarmEntry(id: alarm.id, fireDate: date, isAlerting: alarm.state == .alerting)
        }
        let result = AlarmReconciliation.reconcile(saved: saved, system: entries)
        alarms = result.records
        ringingIDs = result.ringingIDs
        didReadSystemAlarms = true
        persist()

        // When the app is running, retire the completed crescendo as soon as
        // the full-strength alarm alerts. iOS owns both schedules when closed.
        let alerting = Set(entries.filter(\.isAlerting).map(\.id))
        for record in alarms {
            if let continuationID = record.continuationID,
               alerting.contains(continuationID), alerting.contains(record.id) {
                try? AlarmManager.shared.stop(id: record.id)
            }
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(alarms) { defaults.set(data, forKey: Self.storageKey) }
    }
}
