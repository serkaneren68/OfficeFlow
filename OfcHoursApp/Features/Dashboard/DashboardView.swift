import SwiftUI
import Combine

struct DashboardView: View {
    @EnvironmentObject private var state: AppState
    @State private var reveal = false
    @State private var now: Date = .now

    private let liveTicker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var dailyMinutes: Int { state.trackedMinutes(for: .day, at: now) }
    private var dailyTargetHours: Int { state.targetHours(for: .day) }
    private var dailyTargetMinutes: Int { max(1, dailyTargetHours * 60) }
    private var dailyProgress: Double {
        guard dailyTargetHours > 0 else { return 0 }
        return min(1.0, Double(dailyMinutes) / Double(dailyTargetMinutes))
    }

    private var todayDisplay: String {
        let hours = dailyMinutes / 60
        let minutes = dailyMinutes % 60
        return String(format: "%02d:%02d", hours, minutes)
    }

    private var liveSessionDisplay: String? {
        guard let elapsed = state.activeSessionElapsed(at: now) else { return nil }
        let total = max(0, Int(elapsed))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "LIVE %@ %02d:%02d:%02d", h > 0 ? "•" : "", h, m, s).replacingOccurrences(of: "LIVE •", with: "LIVE")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        heroCard
                            .offset(y: reveal ? 0 : 14)
                            .opacity(reveal ? 1 : 0)

                        statusRow
                            .offset(y: reveal ? 0 : 20)
                            .opacity(reveal ? 1 : 0)

                        metricsGrid
                            .offset(y: reveal ? 0 : 26)
                            .opacity(reveal ? 1 : 0)

                        activityCard
                            .offset(y: reveal ? 0 : 32)
                            .opacity(reveal ? 1 : 0)
                    }
                    .padding()
                    .animation(.easeOut(duration: 0.45), value: reveal)
                }
            }
            .navigationTitle("Dashboard")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear { reveal = true }
            .onReceive(liveTicker) { tick in
                now = tick
            }
        }
    }

    private var heroCard: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("TODAY")
                    .font(AppTypography.mono(12))
                    .foregroundStyle(AppPalette.neonCyan)

                Text(todayDisplay)
                    .font(AppTypography.title(52))
                    .foregroundStyle(AppPalette.textPrimary)

                Text(dailyTargetHours > 0 ? "Target: \(dailyTargetHours)h" : "No daily target")
                    .font(AppTypography.body(14))
                    .foregroundStyle(AppPalette.textSecondary)

                HStack(spacing: 8) {
                    statusChip(
                        title: state.isCurrentlyInOffice ? "In Office" : "Outside",
                        color: state.isCurrentlyInOffice ? AppPalette.neonMint : AppPalette.neonAmber,
                        icon: state.isCurrentlyInOffice ? "building.2.fill" : "figure.walk"
                    )

                    if let live = liveSessionDisplay {
                        statusChip(
                            title: live,
                            color: AppPalette.neonCyan,
                            icon: "dot.radiowaves.left.and.right"
                        )
                    }
                }
            }

            Spacer()

            progressGauge
        }
        .neonCard()
    }

    private var progressGauge: some View {
        ZStack {
            Circle()
                .stroke(AppPalette.panelSoft.opacity(0.9), lineWidth: 10)
                .frame(width: 108, height: 108)

            Circle()
                .trim(from: 0, to: dailyProgress)
                .stroke(
                    LinearGradient(
                        colors: [AppPalette.neonCyan, AppPalette.neonMint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .frame(width: 108, height: 108)
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text("\(Int(dailyProgress * 100))%")
                    .font(AppTypography.heading(20))
                    .foregroundStyle(AppPalette.textPrimary)
                Text("Goal")
                    .font(AppTypography.mono(11))
                    .foregroundStyle(AppPalette.textSecondary)
            }
        }
    }

    private var statusRow: some View {
        HStack(spacing: 10) {
            statusTile(
                label: "Tracking",
                value: state.trackingStatusText,
                color: state.isTrackingReady ? AppPalette.neonMint : AppPalette.neonAmber
            )

            statusTile(
                label: "Location",
                value: state.locationPermission == .authorizedAlways ? "Always" : state.locationPermission == .authorizedWhenInUse ? "When In Use" : "Missing",
                color: state.locationPermission == .authorizedAlways ? AppPalette.neonMint : AppPalette.neonAmber
            )

            statusTile(
                label: "Office",
                value: state.office == nil ? "Not Set" : "Configured",
                color: state.office == nil ? AppPalette.neonAmber : AppPalette.neonMint
            )
        }
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            if state.activeTargetPeriods.isEmpty {
                metricCard(title: "Targets", value: "No active target set", icon: "target")
            } else {
                ForEach(state.activeTargetPeriods, id: \.self) { period in
                    metricCard(title: period.rawValue, value: state.progressLabel(for: period), icon: icon(for: period))
                }
            }
            metricCard(title: "Readiness", value: state.isTrackingReady ? "Background active" : "Setup required", icon: "waveform.path.ecg")
        }
    }

    private func icon(for period: ReportPeriod) -> String {
        switch period {
        case .day: return "sun.max.fill"
        case .week: return "calendar"
        case .month: return "calendar.circle"
        }
    }

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent Activity")
                    .font(AppTypography.heading(18))
                    .foregroundStyle(AppPalette.textPrimary)
                Spacer()
                Text("\(state.notificationLog.prefix(4).count) events")
                    .font(AppTypography.mono(11))
                    .foregroundStyle(AppPalette.textSecondary)
            }

            if state.notificationLog.isEmpty {
                Text("No recent entry/exit activity yet.")
                    .font(AppTypography.body(14))
                    .foregroundStyle(AppPalette.textSecondary)
            } else {
                ForEach(Array(state.notificationLog.prefix(4).enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                            .foregroundStyle(AppPalette.neonCyan)
                        Text(row)
                            .font(AppTypography.body(14))
                            .foregroundStyle(AppPalette.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .neonCard()
    }

    private func statusChip(title: String, color: Color, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .font(AppTypography.mono(11))
        .foregroundStyle(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(color.opacity(0.14))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(color.opacity(0.32), lineWidth: 1)
        )
    }

    private func statusTile(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(AppTypography.mono(10))
                .foregroundStyle(AppPalette.textSecondary)
            Text(value)
                .font(AppTypography.heading(13))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppPalette.panelSoft.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }

    private func metricCard(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(AppPalette.neonCyan)
                Text(title.uppercased())
                    .font(AppTypography.mono(11))
                    .foregroundStyle(AppPalette.textSecondary)
            }

            Text(value)
                .font(AppTypography.body(14))
                .foregroundStyle(AppPalette.textPrimary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppPalette.panel.opacity(0.86))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppPalette.neonCyan.opacity(0.16), lineWidth: 1)
        )
    }
}
