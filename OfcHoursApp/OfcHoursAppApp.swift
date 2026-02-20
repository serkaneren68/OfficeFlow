import SwiftUI

@main
struct OfcHoursAppApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
        }
        .onChange(of: scenePhase) { _, newPhase in
            state.handleScenePhaseChange(newPhase)
        }
    }
}
