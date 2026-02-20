import SwiftUI
import MapKit
import CoreLocation
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.openURL) private var openURL
    @State private var showResetConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        overviewCard
                        permissionsCard
                        configurationCard
                        dataCard
                        privacyCard
                    }
                    .padding()
                }
            }
            .navigationTitle("Settings")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear {
                state.refreshSystemPermissions()
            }
            .alert("Reset Statistics?", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    state.resetStatistics()
                }
            } message: {
                Text("This clears timeline events, sessions, notifications and correction history. Office and target settings stay unchanged.")
            }
        }
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TRACKING OVERVIEW")
                .font(AppTypography.mono(12))
                .foregroundStyle(AppPalette.neonCyan)

            HStack {
                Text(state.trackingStatusText)
                    .font(AppTypography.heading(24))
                    .foregroundStyle(state.isTrackingReady ? AppPalette.neonMint : AppPalette.neonAmber)
                Spacer()
                Image(systemName: state.isTrackingReady ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(state.isTrackingReady ? AppPalette.neonMint : AppPalette.neonAmber)
            }

            Text(trackingGuidance)
                .font(AppTypography.body(14))
                .foregroundStyle(AppPalette.textSecondary)
        }
        .neonCard()
    }

    private var permissionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Permissions")

            permissionRow(
                title: "Location",
                stateText: state.locationPermission.rawValue,
                isDeferred: state.locationPermissionDeferred,
                requestTitle: "Request Always",
                requestAction: state.requestLocationPermission,
                deferAction: state.deferLocationPermission,
                guidance: state.locationSettingsGuidance()
            )

            Divider().overlay(AppPalette.panelSoft)

            permissionRow(
                title: "Notifications",
                stateText: state.notificationPermission.rawValue,
                isDeferred: state.notificationPermissionDeferred,
                requestTitle: "Request Notifications",
                requestAction: state.requestNotificationPermission,
                deferAction: state.deferNotificationPermission,
                guidance: state.notificationSettingsGuidance()
            )
        }
        .neonCard()
    }

    private var configurationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Configuration")

            NavigationLink {
                OfficeGeofenceSettingsView()
                    .environmentObject(state)
            } label: {
                configRow(title: "Office Geofence", subtitle: state.office?.name ?? "Not configured", icon: "mappin.and.ellipse")
            }
            .buttonStyle(.plain)

            NavigationLink {
                TargetSettingsView()
                    .environmentObject(state)
            } label: {
                configRow(
                    title: "Target Hours",
                    subtitle: state.activeTargetsSummaryText,
                    icon: "target"
                )
            }
            .buttonStyle(.plain)

        }
        .neonCard()
    }

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Privacy")
            Text("All attendance data remains on your device.")
                .font(AppTypography.body(14))
                .foregroundStyle(AppPalette.textPrimary)
            Text("Cloud sync is disabled in this version.")
                .font(AppTypography.body(13))
                .foregroundStyle(AppPalette.textSecondary)
        }
        .neonCard()
    }

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Data")
            Text("Need a clean start? You can reset tracked statistics without losing configuration.")
                .font(AppTypography.body(13))
                .foregroundStyle(AppPalette.textSecondary)

            Button {
                showResetConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                    Text("Reset Statistics")
                        .font(AppTypography.heading(15))
                }
                .foregroundStyle(AppPalette.neonRed)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(AppPalette.neonRed.opacity(0.14))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(AppPalette.neonRed.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .neonCard()
    }

    @ViewBuilder
    private func permissionRow(
        title: String,
        stateText: String,
        isDeferred: Bool,
        requestTitle: String,
        requestAction: @escaping () -> Void,
        deferAction: @escaping () -> Void,
        guidance: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(AppTypography.heading(16))
                    .foregroundStyle(AppPalette.textPrimary)
                Spacer()
                Text(stateText)
                    .font(AppTypography.mono(12))
                    .foregroundStyle(AppPalette.textSecondary)
            }

            if isDeferred {
                Text("Deferred")
                    .font(AppTypography.mono(12))
                    .foregroundStyle(AppPalette.neonAmber)
            }

            HStack(spacing: 8) {
                buttonChip(title: requestTitle, color: AppPalette.neonCyan, action: requestAction)
                buttonChip(title: "Defer", color: AppPalette.neonAmber, action: deferAction)
                buttonChip(title: "Open Settings", color: AppPalette.neonMint) {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    openURL(url)
                }
            }

            Text(guidance)
                .font(AppTypography.body(12))
                .foregroundStyle(AppPalette.textSecondary)
        }
    }

    private func configRow(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(AppPalette.neonCyan)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.heading(16))
                    .foregroundStyle(AppPalette.textPrimary)
                Text(subtitle)
                    .font(AppTypography.body(13))
                    .foregroundStyle(AppPalette.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(AppPalette.textSecondary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppPalette.panelSoft.opacity(0.75))
        )
    }

    private func buttonChip(title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(AppTypography.mono(11))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(color.opacity(0.15))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(AppTypography.mono(12))
            .foregroundStyle(AppPalette.neonCyan)
    }

    private var trackingGuidance: String {
        if state.isTrackingReady {
            return "Background entry/exit detection is active."
        }
        if state.office == nil {
            return "Set your office geofence to start automatic tracking."
        }
        if state.locationPermission == .authorizedWhenInUse {
            return "Location is limited to foreground. Grant Always for background tracking."
        }
        return "Grant location and notification permissions for full tracking."
    }

}

struct OfficeGeofenceSettingsView: View {
    @EnvironmentObject private var state: AppState

    @State private var officeName: String = ""
    @State private var latitude: String = ""
    @State private var longitude: String = ""
    @State private var radius: String = "150"
    @State private var mapPosition: MapCameraPosition = .automatic

    var body: some View {
        Form {
            Section("Map Setup") {
                TextField("Office Name", text: $officeName)

                MapReader { proxy in
                    Map(position: $mapPosition) {
                        if let officeCoordinate = selectedCoordinate {
                            Annotation("Office", coordinate: officeCoordinate) {
                                Image(systemName: "building.2.fill")
                                    .font(.title3)
                                    .foregroundStyle(.red)
                                    .padding(8)
                                    .background(.thinMaterial, in: Circle())
                            }
                            MapCircle(center: officeCoordinate, radius: parsedRadiusMeters)
                                .foregroundStyle(.red.opacity(0.18))
                        }
                        if let current = state.currentLocationCoordinate {
                            Annotation("You", coordinate: current) {
                                ZStack {
                                    Circle().fill(.blue.opacity(0.22)).frame(width: 34, height: 34)
                                    Circle().fill(.blue).frame(width: 14, height: 14)
                                }
                            }
                        }
                    }
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onTapGesture(coordinateSpace: .local) { point in
                        guard let coordinate = proxy.convert(point, from: .local) else { return }
                        selectCoordinate(coordinate)
                        state.officeValidationMessage = "Office location selected from map."
                    }
                }

                HStack {
                    Button {
                        state.requestCurrentLocation()
                    } label: {
                        Label("My Location", systemImage: "location.fill")
                    }
                    .buttonStyle(.bordered)

                    Button("Use Current Location") {
                        guard let coordinate = state.currentLocationCoordinate else { return }
                        selectCoordinate(coordinate)
                        focusMap(on: coordinate, radiusMeters: parsedRadiusMeters)
                    }
                    .buttonStyle(.bordered)
                    .disabled(state.currentLocationCoordinate == nil)
                }

                if !state.currentLocationMessage.isEmpty {
                    Text(state.currentLocationMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Radius") {
                HStack {
                    Text("Size")
                    Spacer()
                    Text("\(Int(parsedRadiusMeters)) m")
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { parsedRadiusMeters },
                        set: { radius = String(Int($0)) }
                    ),
                    in: 50...1000,
                    step: 10
                )
            }

            Section("Save") {
                Button("Save Geofence") {
                    guard let parsedLatitude = Double(latitude), let parsedLongitude = Double(longitude), let parsedRadius = Double(radius) else {
                        state.officeValidationMessage = "Latitude, longitude, and radius must be numeric."
                        return
                    }
                    state.saveOffice(
                        name: officeName,
                        latitude: parsedLatitude,
                        longitude: parsedLongitude,
                        radiusMeters: parsedRadius
                    )
                }
                .buttonStyle(.borderedProminent)

                Button("Delete Geofence", role: .destructive) {
                    state.clearOffice()
                }
            }

            Section("Advanced") {
                TextField("Latitude", text: $latitude)
                    .keyboardType(.numbersAndPunctuation)
                TextField("Longitude", text: $longitude)
                    .keyboardType(.numbersAndPunctuation)
                TextField("Radius (meters)", text: $radius)
                    .keyboardType(.numbersAndPunctuation)
            }

            if !state.officeValidationMessage.isEmpty {
                Section("Message") {
                    Text(state.officeValidationMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Office Geofence")
        .onAppear {
            loadCurrentValues()
        }
    }

    private var selectedCoordinate: CLLocationCoordinate2D? {
        guard let parsedLatitude = Double(latitude), let parsedLongitude = Double(longitude) else { return nil }
        return CLLocationCoordinate2D(latitude: parsedLatitude, longitude: parsedLongitude)
    }

    private var parsedRadiusMeters: Double {
        let value = Double(radius) ?? 150
        return min(max(value, 50), 1000)
    }

    private func selectCoordinate(_ coordinate: CLLocationCoordinate2D) {
        latitude = String(format: "%.6f", coordinate.latitude)
        longitude = String(format: "%.6f", coordinate.longitude)
    }

    private func focusMap(on coordinate: CLLocationCoordinate2D, radiusMeters: Double) {
        mapPosition = .region(
            MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: max(250, radiusMeters * 2.4),
                longitudinalMeters: max(250, radiusMeters * 2.4)
            )
        )
    }

    private func loadCurrentValues() {
        officeName = state.office?.name ?? ""
        latitude = state.office.map { String($0.latitude) } ?? ""
        longitude = state.office.map { String($0.longitude) } ?? ""
        radius = state.office.map { String(Int($0.radiusMeters)) } ?? "150"

        if let office = state.office {
            focusMap(on: CLLocationCoordinate2D(latitude: office.latitude, longitude: office.longitude), radiusMeters: office.radiusMeters)
        } else if let current = state.currentLocationCoordinate {
            focusMap(on: current, radiusMeters: 250)
        } else {
            mapPosition = .automatic
        }
    }
}

struct TargetSettingsView: View {
    @EnvironmentObject private var state: AppState

    private enum Field: Hashable {
        case daily
        case weekly
        case monthly
    }

    @State private var daily: String = ""
    @State private var weekly: String = ""
    @State private var monthly: String = ""
    @FocusState private var focusedField: Field?

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("TARGET HOURS")
                            .font(AppTypography.mono(12))
                            .foregroundStyle(AppPalette.neonCyan)
                        Text("Set your goals for day, week and month.")
                            .font(AppTypography.body(14))
                            .foregroundStyle(AppPalette.textSecondary)
                    }
                    .neonCard()

                    VStack(spacing: 10) {
                        targetField(title: "Daily Hours", value: $daily, field: .daily)
                        targetField(title: "Weekly Hours", value: $weekly, field: .weekly)
                        targetField(title: "Monthly Hours", value: $monthly, field: .monthly)
                    }
                    .neonCard()

                    Button {
                        focusedField = nil
                        state.updateTargets(
                            daily: Int(daily) ?? -1,
                            weekly: Int(weekly) ?? -1,
                            monthly: Int(monthly) ?? -1
                        )
                    } label: {
                        Text("Save Targets")
                            .font(AppTypography.heading(16))
                            .foregroundStyle(AppPalette.bgEnd)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(AppPalette.neonCyan)
                            )
                    }
                    .buttonStyle(.plain)
                    .neonCard()
                }
                .padding()
            }
        }
        .navigationTitle("Target Hours")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onTapGesture {
            focusedField = nil
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
            }
        }
        .onAppear {
            daily = String(state.targets.dailyHours)
            weekly = String(state.targets.weeklyHours)
            monthly = String(state.targets.monthlyHours)
        }
    }

    @ViewBuilder
    private func targetField(title: String, value: Binding<String>, field: Field) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppTypography.mono(12))
                .foregroundStyle(AppPalette.textSecondary)
            TextField("0", text: value)
                .keyboardType(.numberPad)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .focused($focusedField, equals: field)
                .font(AppTypography.heading(18))
                .foregroundStyle(AppPalette.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppPalette.panelSoft.opacity(0.85))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppPalette.neonCyan.opacity(0.18), lineWidth: 1)
                )
                .onChange(of: value.wrappedValue) { _, newValue in
                    let filtered = newValue.filter { $0.isNumber }
                    if filtered != newValue {
                        value.wrappedValue = filtered
                    }
                }
        }
    }
}
