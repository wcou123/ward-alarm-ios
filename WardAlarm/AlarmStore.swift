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
            dialog = .error("Geef Alarm toestemming via Instellingen → Apps → Alarm → Alarmen. Zonder toestemming wordt er geen alarm ingesteld.")
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
            try AlarmManager.shared.cancel(id: alarm.id)
            alarms.removeAll { $0.id == alarm.id }
            ringingIDs.remove(alarm.id)
            persist()
            statusMessage = "Alarm verwijderd."
            refreshFromSystem()
        } catch {
            // A one-shot alarm might have stopped since the confirmation opened.
            if let current = try? AlarmManager.shared.alarms,
               !current.contains(where: { $0.id == alarm.id }) {
                apply(current)
                statusMessage = "Dit alarm is al gestopt."
            } else {
                dialog = .error("Het alarm is niet verwijderd: \(error.localizedDescription)")
            }
        }
    }

    func stopRinging(_ alarm: AlarmRecord) {
        do {
            try AlarmManager.shared.stop(id: alarm.id)
            refreshFromSystem()
        } catch { dialog = .error("Het alarm kon niet worden gestopt: \(error.localizedDescription)") }
    }

    private func schedule(fireDate: Date, isTest: Bool = false) async throws {
        soundPreview.stop()
        let record = AlarmRecord(fireDate: fireDate, isTest: isTest)
        let presentation = AlarmPresentation.Alert(
            title: isTest ? "Testalarm" : "Alarm",
            stopButton: AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.circle")
        )
        let attributes = AlarmAttributes<WardAlarmMetadata>(
            presentation: AlarmPresentation(alert: presentation),
            metadata: WardAlarmMetadata(),
            tintColor: Color(red: 0.12, green: 0.24, blue: 0.40)
        )
        let configuration = AlarmManager.AlarmConfiguration<WardAlarmMetadata>.alarm(
            schedule: .fixed(fireDate),
            attributes: attributes,
            sound: .named("windows-alarm.wav")
        )
        _ = try await AlarmManager.shared.schedule(id: record.id, configuration: configuration)
        // An update may arrive while schedule is suspended: replace only this ID.
        alarms.removeAll { $0.id == record.id }
        alarms.append(record)
        alarms.sort { $0.fireDate < $1.fireDate }
        persist()
        statusMessage = "Alarm ingesteld \(AlarmDateText.target(record))."
        refreshFromSystem()
    }

    private func apply(_ snapshot: [Alarm]) {
        let saved = Dictionary(alarms.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        alarms = snapshot.compactMap { alarm in
            if let record = saved[alarm.id] { return record }
            // Reconstruct fixed alarms if local data was lost; iOS is authoritative.
            if let schedule = alarm.schedule, case .fixed(let date) = schedule {
                return AlarmRecord(id: alarm.id, fireDate: date)
            }
            return nil
        }.sorted { $0.fireDate < $1.fireDate }
        ringingIDs = Set(snapshot.filter { $0.state == .alerting }.map(\.id))
        didReadSystemAlarms = true
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(alarms) { defaults.set(data, forKey: Self.storageKey) }
    }
}
