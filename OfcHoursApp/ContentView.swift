import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        Group {
            if state.requiresOfficeSetup {
                NavigationStack {
                    OnboardingView()
                        .environmentObject(state)
                }
            } else {
                TabView {
                    DashboardView()
                        .tabItem {
                            Label("Dashboard", systemImage: "gauge")
                        }

                    ReportsView()
                        .tabItem {
                            Label("Reports", systemImage: "chart.bar")
                        }

                    TimelineView()
                        .tabItem {
                            Label("Timeline", systemImage: "clock")
                        }

                    SettingsView()
                        .tabItem {
                            Label("Settings", systemImage: "gearshape")
                        }
                }
                .tint(AppPalette.neonCyan)
            }
        }
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(AppPalette.panel)
            appearance.stackedLayoutAppearance.normal.iconColor = UIColor(AppPalette.textSecondary)
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(AppPalette.textSecondary)]
            appearance.stackedLayoutAppearance.selected.iconColor = UIColor(AppPalette.neonCyan)
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(AppPalette.neonCyan)]
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
