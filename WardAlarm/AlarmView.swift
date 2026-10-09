import AlarmKit
import SwiftUI

@MainActor
struct AlarmView: View {
    @ObservedObject var store: AlarmStore
    @State private var hours = 3
    @State private var minutes = 0
    @State private var clockTime = Date()

    private let ink = Color(red: 0.12, green: 0.24, blue: 0.40)
    private let paper = Color(red: 0.96, green: 0.95, blue: 0.92)
    private var duration: TimeInterval { TimeInterval(hours * 3600 + minutes * 60) }
    private var durationIsValid: Bool { duration >= 60 && duration <= AlarmTime.maximumDuration }
    private var durationLabel: String {
        if hours == 0 { return "\(minutes) min" }
        if minutes == 0 { return "\(hours) uur" }
        return "\(hours) uur en \(minutes) min"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    permissionCard
                    durationCard
                    clockCard
                    overview
                    soundCard
                    Text("Je iPhone beheert de ingestelde alarmen. Je hoeft deze app niet open te houden.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
                .padding(20)
                .frame(maxWidth: 650)
                .frame(maxWidth: .infinity)
            }
            .background(paper)
            .tint(ink)
            .toolbar(.hidden, for: .navigationBar)
            .alert(item: $store.dialog) { dialog in
                switch dialog {
                case .remove(let alarm):
                    return Alert(
                        title: Text("Alarm verwijderen?"),
                        message: Text("Wil je het alarm \(AlarmDateText.target(alarm)) verwijderen?"),
                        primaryButton: .destructive(Text("Verwijder")) { store.removeConfirmed(alarm) },
                        secondaryButton: .cancel(Text("Annuleer"))
                    )
                case .error(let message):
                    return Alert(title: Text("Niet gelukt"), message: Text(message), dismissButton: .default(Text("OK")))
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "alarm.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(ink)
                .frame(width: 54, height: 54)
                .background(.white, in: RoundedRectangle(cornerRadius: 18))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Alarm").font(.largeTitle.bold()).foregroundStyle(ink)
                Text("Een alarm, wanneer jij het nodig hebt.").font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var permissionCard: some View {
        if store.authorization != .authorized {
            card {
                Label("Geef je iPhone toestemming om alarmen te laten afgaan.", systemImage: "bell.badge")
                    .font(.subheadline)
                if store.authorization == .denied {
                    Button("Open instellingen") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }.buttonStyle(.bordered)
                } else {
                    Button("Activeer alarmen") { Task { _ = await store.authorize() } }
                        .buttonStyle(.bordered)
                        .disabled(store.isBusy)
                }
            }
        }
    }

    private var durationCard: some View {
        card {
            Text("Binnen een tijdje").font(.headline)
            HStack(spacing: 12) {
                Picker("Uur", selection: $hours) {
                    ForEach(0...168, id: \.self) { Text("\($0) uur").tag($0) }
                }
                Picker("Minuten", selection: $minutes) {
                    ForEach(0...59, id: \.self) { Text("\($0) min").tag($0) }
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)
            Button {
                Task { await store.add(after: duration) }
            } label: {
                Label("Alarm binnen \(durationLabel)", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 34)
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.isBusy || !durationIsValid)
            HStack(spacing: 8) {
                quickButton("15 min", seconds: 15 * 60)
                quickButton("1 uur", seconds: 3600)
                quickButton("3 uur", seconds: AlarmTime.defaultDuration)
            }
        }
    }

    private func quickButton(_ title: String, seconds: TimeInterval) -> some View {
        Button(title) { Task { await store.add(after: seconds) } }
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity, minHeight: 32)
            .buttonStyle(.bordered)
            .disabled(store.isBusy)
    }

    private var clockCard: some View {
        card {
            Text("Op een tijdstip").font(.headline)
            DatePicker("Tijdstip", selection: $clockTime, displayedComponents: .hourAndMinute)
                .environment(\.locale, Locale(identifier: "nl_BE"))
            Button("Stel alarm in op \(AlarmDateText.time(clockTime))") {
                Task { await store.add(at: clockTime) }
            }
            .buttonStyle(.bordered)
            .disabled(store.isBusy)
            Text("Is het tijdstip vandaag al voorbij, dan gaat het alarm morgen af.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Actieve alarmen").font(.title3.bold()).foregroundStyle(ink)
                Spacer()
                Text("\(store.alarms.count)")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white, in: Capsule())
            }
            if let message = store.statusMessage {
                Text(message).font(.subheadline).foregroundStyle(ink).accessibilityIdentifier("alarm-status")
            }
            if !store.didReadSystemAlarms && !store.alarms.isEmpty {
                Text("De opgeslagen alarmen zijn nog niet bij je iPhone bevestigd.")
                    .font(.subheadline).foregroundStyle(.orange)
            }
            if store.alarms.isEmpty {
                card {
                    Text("Nog geen actieve alarmen.").foregroundStyle(.secondary)
                    Text("Een nieuw alarm komt erbij. Eerdere alarmen blijven staan.").font(.footnote).foregroundStyle(.secondary)
                }
            } else {
                ForEach(store.alarms) { alarm in
                    card {
                        HStack(alignment: .center, spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(AlarmDateText.time(alarm.fireDate, includeSeconds: alarm.isTest))
                                    .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(ink)
                                Text(AlarmDateText.day(alarm.fireDate)).font(.subheadline).foregroundStyle(.secondary)
                                if alarm.isTest { Text("Testalarm").font(.caption).foregroundStyle(.secondary) }
                                if store.ringingIDs.contains(alarm.id) {
                                    Label("Alarm gaat af", systemImage: "bell.fill").font(.subheadline.bold()).foregroundStyle(ink)
                                }
                            }
                            Spacer(minLength: 0)
                            VStack(spacing: 8) {
                                if store.ringingIDs.contains(alarm.id) {
                                    Button("Stop") { store.stopRinging(alarm) }.buttonStyle(.borderedProminent)
                                }
                                Button("Verwijder", role: .destructive) { store.requestRemoval(of: alarm) }
                                    .buttonStyle(.bordered)
                                    .disabled(store.isBusy)
                                    .accessibilityLabel("Verwijder alarm \(AlarmDateText.target(alarm))")
                            }
                        }
                    }
                }
            }
        }
    }

    private var soundCard: some View {
        card {
            Text("Controleer je alarm").font(.headline)
            SoundTestButton(preview: store.soundPreview) { store.dialog = .error($0) }
            Button {
                Task { await store.testLockedScreenAlarm() }
            } label: {
                Label("Test alarm over 10 seconden", systemImage: "iphone.gen3")
            }
            .buttonStyle(.bordered)
            .disabled(store.isBusy)
            Text("Vergrendel na deze knop je iPhone. Controleer of je het Windows-alarmgeluid hoort.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14, content: content)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(.white, in: RoundedRectangle(cornerRadius: 20))
    }
}

@MainActor
private struct SoundTestButton: View {
    @ObservedObject var preview: SoundPreview
    let onError: (String) -> Void

    var body: some View {
        Button {
            if preview.isPlaying { preview.stop() }
            else {
                do { try preview.play() }
                catch { onError(error.localizedDescription) }
            }
        } label: {
            Label(preview.isPlaying ? "Stop testgeluid" : "Test Windows-alarmgeluid", systemImage: preview.isPlaying ? "stop.fill" : "speaker.wave.2.fill")
        }
        .buttonStyle(.bordered)
    }
}
