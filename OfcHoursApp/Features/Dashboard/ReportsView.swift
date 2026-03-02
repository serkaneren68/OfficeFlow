import SwiftUI

struct ReportsView: View {
    @EnvironmentObject private var state: AppState
    @State private var reveal = false
    private var calendar: Calendar {
        var value = Calendar.current
        value.locale = AppLocalization.locale()
        return value
    }

    private var availablePeriods: [ReportPeriod] {
        state.activeTargetPeriods.isEmpty ? ReportPeriod.allCases : state.activeTargetPeriods
    }

    private var selectedProgress: String {
        let selected = availablePeriods.contains(state.selectedReportPeriod) ? state.selectedReportPeriod : (availablePeriods.first ?? .day)
        return state.progressLabel(for: selected)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        heroCard
                            .offset(y: reveal ? 0 : 10)
                            .opacity(reveal ? 1 : 0)

                        periodCard
                            .offset(y: reveal ? 0 : 16)
                            .opacity(reveal ? 1 : 0)

                        monthCalendarCard
                            .offset(y: reveal ? 0 : 20)
                            .opacity(reveal ? 1 : 0)

                        statsGrid
                            .offset(y: reveal ? 0 : 24)
                            .opacity(reveal ? 1 : 0)

                        alertsCard
                            .offset(y: reveal ? 0 : 30)
                            .opacity(reveal ? 1 : 0)
                    }
                    .padding()
                    .animation(.easeOut(duration: 0.45), value: reveal)
                }
            }
            .navigationTitle("Reports")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear { reveal = true }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PERFORMANCE OVERVIEW")
                .font(AppTypography.mono(12))
                .foregroundStyle(AppPalette.neonCyan)

            Text(selectedProgress)
                .font(AppTypography.heading(28))
                .foregroundStyle(AppPalette.textPrimary)

            Text("Compare your tracked office time against your configured target.")
                .font(AppTypography.body(14))
                .foregroundStyle(AppPalette.textSecondary)
        }
        .neonCard()
    }

    private var periodCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PERIOD")
                .font(AppTypography.mono(12))
                .foregroundStyle(AppPalette.neonCyan)

            Picker("Period", selection: $state.selectedReportPeriod) {
                ForEach(availablePeriods, id: \.self) { period in
                    Text(period.localizedTitle).tag(period)
                }
            }
            .pickerStyle(.segmented)
        }
        .neonCard()
        .onAppear {
            if !availablePeriods.contains(state.selectedReportPeriod), let first = availablePeriods.first {
                state.selectedReportPeriod = first
            }
        }
    }

    private var monthCalendarCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CURRENT MONTH")
                .font(AppTypography.mono(12))
                .foregroundStyle(AppPalette.neonCyan)

            Text(currentMonthTitle)
                .font(AppTypography.heading(20))
                .foregroundStyle(AppPalette.textPrimary)

            HStack(spacing: 8) {
                sourceLegendBadge(
                    title: AppLocalization.text("reports.calendar.auto", fallback: "Auto"),
                    color: AppPalette.neonAmber
                )
                sourceLegendBadge(
                    title: AppLocalization.text("reports.calendar.manual", fallback: "Manual"),
                    color: AppPalette.neonMint
                )
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(AppTypography.mono(10))
                        .foregroundStyle(AppPalette.textSecondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(monthCells) { cell in
                    dayCell(cell)
                }
            }
        }
        .neonCard()
    }

    private func dayCell(_ cell: CalendarCell) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppPalette.panel.opacity(cell.date == nil ? 0.3 : 0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(cell.isToday ? AppPalette.neonCyan.opacity(0.75) : AppPalette.neonCyan.opacity(0.12), lineWidth: cell.isToday ? 1.5 : 1)
                )

            if let day = cell.day {
                VStack(spacing: 2) {
                    Text("\(day)")
                        .font(AppTypography.mono(11))
                        .foregroundStyle(AppPalette.textPrimary)

                    Text(formattedHours(minutes: cell.minutes))
                        .font(AppTypography.mono(9))
                        .foregroundStyle(cell.minutes > 0 ? AppPalette.neonAmber : AppPalette.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    if cell.geofenceEventCount > 0 || cell.manualEventCount > 0 {
                        HStack(spacing: 3) {
                            if cell.geofenceEventCount > 0 {
                                eventCountBadge(
                                    label: AppLocalization.format(
                                        "reports.calendar.autoBadge",
                                        cell.geofenceEventCount,
                                        fallback: "A:%d"
                                    ),
                                    color: AppPalette.neonAmber
                                )
                            }
                            if cell.manualEventCount > 0 {
                                eventCountBadge(
                                    label: AppLocalization.format(
                                        "reports.calendar.manualBadge",
                                        cell.manualEventCount,
                                        fallback: "M:%d"
                                    ),
                                    color: AppPalette.neonMint
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .frame(height: 48)
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            if state.activeTargetPeriods.isEmpty {
                metricCard(
                    title: AppLocalization.text("dashboard.targets", fallback: "Targets"),
                    icon: "target",
                    value: AppLocalization.text("dashboard.targets.none", fallback: "No active target set")
                )
            } else {
                ForEach(state.activeTargetPeriods, id: \.self) { period in
                    metricCard(title: period.localizedTitle, icon: icon(for: period), value: state.progressLabel(for: period))
                }
            }
            metricCard(
                title: AppLocalization.text("dashboard.tracking", fallback: "Tracking"),
                icon: "dot.radiowaves.left.and.right",
                value: state.isTrackingReady
                    ? AppLocalization.text("reports.tracking.active", fallback: "Auto tracking active")
                    : AppLocalization.text("dashboard.readiness.required", fallback: "Setup required")
            )
        }
    }

    private func icon(for period: ReportPeriod) -> String {
        switch period {
        case .day: return "sun.max.fill"
        case .week: return "calendar"
        case .month: return "calendar.circle"
        }
    }

    private var currentMonthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        formatter.locale = AppLocalization.locale()
        return formatter.string(from: Date())
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let index = max(0, min(symbols.count - 1, calendar.firstWeekday - 1))
        return Array(symbols[index...] + symbols[..<index]).map { $0.uppercased() }
    }

    private var monthCells: [CalendarCell] {
        let now = Date()
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: now),
            let dayRange = calendar.range(of: .day, in: .month, for: monthInterval.start)
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingEmptyCount = (firstWeekday - calendar.firstWeekday + 7) % 7

        var cells: [CalendarCell] = []
        for index in 0..<leadingEmptyCount {
            cells.append(
                CalendarCell(
                    id: "empty-\(index)",
                    day: nil,
                    date: nil,
                    minutes: 0,
                    isToday: false,
                    geofenceEventCount: 0,
                    manualEventCount: 0
                )
            )
        }

        let dayEventCounts = eventCountsByDay
        for day in dayRange {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start) else { continue }
            let minutes = state.trackedMinutes(for: .day, at: date)
            let isToday = calendar.isDate(date, inSameDayAs: now)
            let normalized = calendar.startOfDay(for: date)
            let counts = dayEventCounts[normalized] ?? (geofence: 0, manual: 0)
            cells.append(
                CalendarCell(
                    id: "day-\(day)",
                    day: day,
                    date: date,
                    minutes: minutes,
                    isToday: isToday,
                    geofenceEventCount: counts.geofence,
                    manualEventCount: counts.manual
                )
            )
        }

        let trailing = (7 - (cells.count % 7)) % 7
        for index in 0..<trailing {
            cells.append(
                CalendarCell(
                    id: "tail-\(index)",
                    day: nil,
                    date: nil,
                    minutes: 0,
                    isToday: false,
                    geofenceEventCount: 0,
                    manualEventCount: 0
                )
            )
        }
        return cells
    }

    private var eventCountsByDay: [Date: (geofence: Int, manual: Int)] {
        var counts: [Date: (geofence: Int, manual: Int)] = [:]
        for event in state.events {
            let day = calendar.startOfDay(for: event.timestamp)
            var value = counts[day] ?? (geofence: 0, manual: 0)
            switch event.source {
            case .geofence:
                value.geofence += 1
            case .manual:
                value.manual += 1
            }
            counts[day] = value
        }
        return counts
    }

    private func formattedHours(minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        if remainder == 0 {
            return AppLocalization.format("reports.hoursOnly", hours, fallback: "%dh")
        }
        return AppLocalization.format("reports.hoursMinutes", hours, remainder, fallback: "%dh %dm")
    }

    private var alertsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SYSTEM INSIGHTS")
                .font(AppTypography.mono(12))
                .foregroundStyle(AppPalette.neonCyan)

            if state.smartAlerts.isEmpty {
                Text("Everything looks stable. No active issue detected.")
                    .font(AppTypography.body(14))
                    .foregroundStyle(AppPalette.textSecondary)
            } else {
                ForEach(state.smartAlerts, id: \.self) { alert in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "waveform.path.ecg")
                            .foregroundStyle(AppPalette.neonAmber)
                        Text(alert)
                            .font(AppTypography.body(14))
                            .foregroundStyle(AppPalette.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .neonCard()
    }

    private func metricCard(title: String, icon: String, value: String) -> some View {
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

    private func sourceLegendBadge(title: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(title)
                .font(AppTypography.mono(10))
                .foregroundStyle(AppPalette.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(AppPalette.panelSoft.opacity(0.75))
        )
    }

    private func eventCountBadge(label: String, color: Color) -> some View {
        Text(label)
            .font(AppTypography.mono(8))
            .foregroundStyle(color)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(
                Capsule(style: .continuous)
                    .fill(color.opacity(0.16))
            )
    }
}

private struct CalendarCell: Identifiable {
    let id: String
    let day: Int?
    let date: Date?
    let minutes: Int
    let isToday: Bool
    let geofenceEventCount: Int
    let manualEventCount: Int
}
