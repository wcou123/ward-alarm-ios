import SwiftUI

@main
@MainActor
struct WardAlarmApp: App {
    @StateObject private var store = AlarmStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            AlarmView(store: store)
                .task { store.startObserving() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { store.refreshFromSystem() }
                    else { store.soundPreview.stop() }
                }
        }
    }
}
