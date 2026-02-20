import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        ZStack {
            AppBackground()
            VStack(alignment: .leading, spacing: 10) {
                Text("Initial Setup")
                    .font(AppTypography.heading(28))
                    .foregroundStyle(AppPalette.textPrimary)
                Text("Select and save your office location to start automatic office hour tracking.")
                    .font(AppTypography.body(15))
                    .foregroundStyle(AppPalette.textSecondary)
                if let office = state.office {
                    Text("Configured: \(office.name)")
                        .font(AppTypography.mono(12))
                        .foregroundStyle(AppPalette.neonMint)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)

            OfficeGeofenceSettingsView()
                .environmentObject(state)
                .padding(.top, 92)
        }
        .navigationTitle("Office Location")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
