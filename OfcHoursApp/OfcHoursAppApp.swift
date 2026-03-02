import SwiftUI

@main
struct OfcHoursAppApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppLocalization.languagePreferenceKey) private var preferredLanguageCode: String = SupportedLanguage.system.rawValue
    @StateObject private var state = AppState()

    private var selectedLanguage: SupportedLanguage {
        SupportedLanguage(rawValue: preferredLanguageCode) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.locale, AppLocalization.locale(for: selectedLanguage))
                .environmentObject(state)
                .onChange(of: preferredLanguageCode) { _, _ in
                    state.handleLanguagePreferenceChanged()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            state.handleScenePhaseChange(newPhase)
        }
    }
}
