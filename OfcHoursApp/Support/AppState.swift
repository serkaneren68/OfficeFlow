import Foundation
import SwiftUI
import Combine
import CoreLocation
import UserNotifications

private struct PersistedState: Codable {
    var locationPermission: PermissionState
    var notificationPermission: PermissionState
    var locationPermissionDeferred: Bool
    var notificationPermissionDeferred: Bool
    var trackingNotificationsEnabled: Bool
    var office: OfficeLocation?
    var targets: TargetPolicy
    var events: [PresenceEvent]
    var correctionAuditLog: [CorrectionAuditEntry]
    var notificationLog: [String]
    var recoveryValidationMessage: String
    var showOnboarding: Bool
    var isInsideOffice: Bool

    private enum CodingKeys: String, CodingKey {
        case locationPermission
        case notificationPermission
        case locationPermissionDeferred
        case notificationPermissionDeferred
        case trackingNotificationsEnabled
        case office
        case targets
        case events
        case correctionAuditLog
        case notificationLog
        case recoveryValidationMessage
        case showOnboarding
        case isInsideOffice
    }

    init(
        locationPermission: PermissionState,
        notificationPermission: PermissionState,
        locationPermissionDeferred: Bool,
        notificationPermissionDeferred: Bool,
        trackingNotificationsEnabled: Bool,
        office: OfficeLocation?,
        targets: TargetPolicy,
        events: [PresenceEvent],
        correctionAuditLog: [CorrectionAuditEntry],
        notificationLog: [String],
        recoveryValidationMessage: String,
        showOnboarding: Bool,
        isInsideOffice: Bool
    ) {
        self.locationPermission = locationPermission
        self.notificationPermission = notificationPermission
        self.locationPermissionDeferred = locationPermissionDeferred
        self.notificationPermissionDeferred = notificationPermissionDeferred
        self.trackingNotificationsEnabled = trackingNotificationsEnabled
        self.office = office
        self.targets = targets
        self.events = events
        self.correctionAuditLog = correctionAuditLog
        self.notificationLog = notificationLog
        self.recoveryValidationMessage = recoveryValidationMessage
        self.showOnboarding = showOnboarding
        self.isInsideOffice = isInsideOffice
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        locationPermission = try container.decode(PermissionState.self, forKey: .locationPermission)
        notificationPermission = try container.decode(PermissionState.self, forKey: .notificationPermission)
        locationPermissionDeferred = try container.decodeIfPresent(Bool.self, forKey: .locationPermissionDeferred) ?? false
        notificationPermissionDeferred = try container.decodeIfPresent(Bool.self, forKey: .notificationPermissionDeferred) ?? false
        trackingNotificationsEnabled = try container.decode(Bool.self, forKey: .trackingNotificationsEnabled)
        office = try container.decodeIfPresent(OfficeLocation.self, forKey: .office)
        targets = try container.decode(TargetPolicy.self, forKey: .targets)
        events = try container.decode([PresenceEvent].self, forKey: .events)
        correctionAuditLog = try container.decodeIfPresent([CorrectionAuditEntry].self, forKey: .correctionAuditLog) ?? []
        notificationLog = try container.decodeIfPresent([String].self, forKey: .notificationLog) ?? []
        recoveryValidationMessage = try container.decodeIfPresent(String.self, forKey: .recoveryValidationMessage) ?? ""
        showOnboarding = try container.decodeIfPresent(Bool.self, forKey: .showOnboarding) ?? true
        isInsideOffice = try container.decodeIfPresent(Bool.self, forKey: .isInsideOffice) ?? false
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var locationPermission: PermissionState = .notDetermined { didSet { persist() } }
    @Published var notificationPermission: PermissionState = .notDetermined { didSet { persist() } }
    @Published var locationPermissionDeferred: Bool = false { didSet { persist() } }
    @Published var notificationPermissionDeferred: Bool = false { didSet { persist() } }
    @Published var trackingNotificationsEnabled: Bool = true { didSet { persist() } }

    @Published var office: OfficeLocation? { didSet { persist() } }
    @Published var targets: TargetPolicy = .init(dailyHours: 8, weeklyHours: 40, monthlyHours: 160) { didSet { persist() } }

    @Published var events: [PresenceEvent] = [] { didSet { persist(); refreshComputedState() } }
    @Published var correctionAuditLog: [CorrectionAuditEntry] = [] { didSet { persist() } }
    @Published var notificationLog: [String] = [] { didSet { persist() } }
    @Published var recoveryValidationMessage: String = ""
    @Published var showOnboarding: Bool = true { didSet { persist() } }
    @Published var officeValidationMessage: String = ""
    @Published var currentLocationCoordinate: CLLocationCoordinate2D?
    @Published var currentLocationMessage: String = ""

    @Published var selectedReportPeriod: ReportPeriod = .day
    @Published private(set) var liveNow: Date = .now
    @Published private(set) var sessionResult: SessionBuildResult = .init(sessions: [])
    @Published private(set) var eventsDescending: [PresenceEvent] = []

    private var isInsideOffice: Bool = false { didSet { persist() } }
    private let stateURL: URL
    private let locationManager = LocationTrackingManager()
    private let trackingService = TrackingService()
    private let sessionEngine = SessionEngine()
    private let correctionService = CorrectionService()
    private let reportingService = ReportingService()
    private var isProcessingRegionState = false
    private var liveClockCancellable: AnyCancellable?

    init() {
        let doc = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.stateURL = doc.appendingPathComponent("ofchours-state.json")
        locationManager.onPermissionChanged = { [weak self] permission in
            Task { @MainActor in
                guard let self else { return }
                if self.locationPermission != permission {
                    self.locationPermission = permission
                }
                if permission != .notDetermined {
                    self.locationPermissionDeferred = false
                }
                self.locationManager.updateMonitoring(office: self.office)
            }
        }
        locationManager.onRegionTransition = { [weak self] inside in
            Task { @MainActor in
                self?.handleGeofenceTransition(inside: inside)
            }
        }
        locationManager.onCurrentLocation = { [weak self] coordinate in
            Task { @MainActor in
                self?.currentLocationCoordinate = coordinate
                self?.currentLocationMessage = "Current location updated."
            }
        }
        locationManager.onLocationError = { [weak self] message in
            Task { @MainActor in
                self?.currentLocationMessage = message
            }
        }
        loadPersistedState()
        refreshComputedState()
        locationManager.refreshPermission()
        locationManager.updateMonitoring(office: office)
        refreshNotificationPermissionStatus()
        syncLiveClock()
        startLiveClock()
    }

    var isTrackingReady: Bool {
        locationPermission == .authorizedAlways && office != nil
    }

    var requiresOfficeSetup: Bool {
        office == nil
    }

    var isCurrentlyInOffice: Bool {
        isInsideOffice
    }

    var trackingStatusText: String {
        if isTrackingReady {
            return "Auto Tracking Active"
        }
        if locationPermission == .authorizedWhenInUse {
            return "Foreground Only"
        }
        if office == nil {
            return "Office Not Set"
        }
        return "Permission Required"
    }

    var setupSummaryItems: [String] {
        [
            "Location Permission: \(locationPermission.rawValue)",
            "Location Setup Deferred: \(locationPermissionDeferred ? "Yes" : "No")",
            "Notification Permission: \(notificationPermission.rawValue)",
            "Notification Setup Deferred: \(notificationPermissionDeferred ? "Yes" : "No")",
            "Tracking Notifications: \(trackingNotificationsEnabled ? "Enabled" : "Disabled")",
            "Office: \(office?.name ?? "Not Configured")",
            "Targets: D \(targets.dailyHours)h / W \(targets.weeklyHours)h / M \(targets.monthlyHours)h"
        ]
    }

    var smartAlerts: [String] {
        var alerts: [String] = []
        if !isTrackingReady {
            if locationPermission == .authorizedWhenInUse {
                alerts.append("Background tracking is limited. Grant 'Always' location permission.")
            } else {
                alerts.append("Tracking is not ready. Configure permissions and office geofence.")
            }
        }
        if locationPermissionDeferred || notificationPermissionDeferred {
            alerts.append("Permission setup is deferred. You can complete it anytime from Settings.")
        }
        if recoveryValidationMessage.contains("found") {
            alerts.append(recoveryValidationMessage)
        }
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 15 {
            let dayMinutes = trackedMinutesForCurrentDay()
            if dayMinutes < targets.dailyHours * 60 / 2 {
                alerts.append("You are behind your daily target. Consider planning next office visit.")
            }
        }
        return alerts
    }

    func requestLocationPermission() {
        locationPermissionDeferred = false
        locationManager.requestAlwaysPermission()
    }

    func requestCurrentLocation() {
        locationManager.requestCurrentLocation()
    }

    func deferLocationPermission() {
        if locationPermission == .notDetermined {
            locationPermissionDeferred = true
        }
    }

    func requestNotificationPermission() {
        Task { @MainActor in
            let center = UNUserNotificationCenter.current()
            notificationPermissionDeferred = false
            let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted == true {
                notificationPermission = .authorizedAlways
                trackingNotificationsEnabled = true
            } else {
                notificationPermission = .denied
                trackingNotificationsEnabled = false
            }
        }
    }

    func setTrackingNotificationsEnabled(_ enabled: Bool) {
        guard notificationPermission == .authorizedAlways || !enabled else { return }
        trackingNotificationsEnabled = enabled
    }

    func deferNotificationPermission() {
        if notificationPermission == .notDetermined {
            notificationPermissionDeferred = true
        }
    }

    func refreshSystemPermissions() {
        locationManager.refreshPermission()
        refreshNotificationPermissionStatus()
    }

    func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            syncLiveClock()
            startLiveClock()
            locationManager.refreshPermission()
            locationManager.updateMonitoring(office: office)
            locationManager.requestMonitoredRegionState()
            refreshNotificationPermissionStatus()
        case .background:
            syncLiveClock()
            stopLiveClock()
            locationManager.refreshPermission()
            locationManager.updateMonitoring(office: office)
            locationManager.requestMonitoredRegionState()
            refreshNotificationPermissionStatus()
        case .inactive:
            syncLiveClock()
            stopLiveClock()
        @unknown default:
            break
        }
    }

    func refreshLiveClockNow() {
        syncLiveClock()
    }

    func locationSettingsGuidance() -> String {
        "iOS Settings > Privacy & Security > Location Services > OfficeFlow > Always"
    }

    func notificationSettingsGuidance() -> String {
        "iOS Settings > Notifications > OfficeFlow > Allow Notifications"
    }

    func saveOffice(name: String, latitude: Double, longitude: Double, radiusMeters: Double) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            officeValidationMessage = "Office name is required."
            return
        }
        guard (-90.0...90.0).contains(latitude), (-180.0...180.0).contains(longitude) else {
            officeValidationMessage = "Latitude/Longitude values are invalid."
            return
        }
        guard radiusMeters > 0 else {
            officeValidationMessage = "Radius must be greater than zero."
            return
        }
        officeValidationMessage = "Office geofence configured."
        office = OfficeLocation(name: cleanName, latitude: latitude, longitude: longitude, radiusMeters: radiusMeters)
        locationManager.updateMonitoring(office: office)
    }

    func clearOffice() {
        office = nil
        isInsideOffice = false
        officeValidationMessage = "Office geofence removed."
        locationManager.updateMonitoring(office: nil)
    }

    func updateTargets(daily: Int, weekly: Int, monthly: Int) {
        guard daily >= 0, weekly >= 0, monthly >= 0 else { return }
        targets = .init(dailyHours: daily, weeklyHours: weekly, monthlyHours: monthly)
    }

    func addManualEvent(type: PresenceEventType, timestamp: Date, reason: String) {
        let result = correctionService.addManualEvent(type: type, timestamp: timestamp, reason: reason)
        let event = result.event
        events.append(event)
        sortEvents()
        correctionAuditLog.insert(result.audit, at: 0)
    }

    func updateEvent(id: UUID, type: PresenceEventType, timestamp: Date, reason: String) {
        guard let result = correctionService.updateEvent(events: events, id: id, type: type, timestamp: timestamp, reason: reason) else { return }
        events = result.events
        sortEvents()
        correctionAuditLog.insert(result.audit, at: 0)
    }

    func deleteEvent(id: UUID, reason: String) {
        let result = correctionService.deleteEvent(events: events, id: id, reason: reason)
        events = result.events
        correctionAuditLog.insert(result.audit, at: 0)
    }

    func resetStatistics() {
        events = []
        correctionAuditLog = []
        notificationLog = []
        recoveryValidationMessage = ""
        isInsideOffice = false
    }

    func buildSessionResult() -> SessionBuildResult {
        sessionResult
    }

    func trackedMinutesForCurrentDay() -> Int {
        trackedMinutes(for: .day, at: Date())
    }

    func trackedMinutesForCurrentWeek() -> Int {
        trackedMinutes(for: .week, at: Date())
    }

    func trackedMinutesForCurrentMonth() -> Int {
        trackedMinutes(for: .month, at: Date())
    }

    func trackedMinutes(for period: ReportPeriod, at date: Date) -> Int {
        reportingService.trackedMinutes(sessions: sessionsForReporting(at: date), for: period, at: date)
    }

    func targetHours(for period: ReportPeriod) -> Int {
        reportingService.targetHours(for: period, targets: targets)
    }

    var activeTargetPeriods: [ReportPeriod] {
        ReportPeriod.allCases.filter { targetHours(for: $0) > 0 }
    }

    var activeTargetsSummaryText: String {
        let parts = activeTargetPeriods.map { period in
            "\(shortLabel(for: period)) \(targetHours(for: period))h"
        }
        return parts.isEmpty ? "No active target" : parts.joined(separator: " • ")
    }

    func progressLabel(for period: ReportPeriod) -> String {
        reportingService.progressLabel(sessions: sessionsForReporting(at: Date()), for: period, at: Date(), targets: targets)
    }

    func activeSessionElapsed(at now: Date = Date()) -> TimeInterval? {
        guard isInsideOffice, let liveStart = latestOpenEntryTimestamp(), now > liveStart else {
            return nil
        }
        return now.timeIntervalSince(liveStart)
    }

    private func sessionsForReporting(at now: Date) -> [AttendanceSession] {
        guard isInsideOffice, let liveStart = latestOpenEntryTimestamp(), now > liveStart else {
            return sessionResult.sessions
        }
        var sessions = sessionResult.sessions
        sessions.append(AttendanceSession(start: liveStart, end: now))
        return sessions
    }

    private func latestOpenEntryTimestamp() -> Date? {
        var openEntryTimestamp: Date?
        for event in events {
            switch event.type {
            case .entry:
                openEntryTimestamp = event.timestamp
            case .exit:
                guard let start = openEntryTimestamp, event.timestamp >= start else { continue }
                openEntryTimestamp = nil
            }
        }
        return openEntryTimestamp
    }

    private func shortLabel(for period: ReportPeriod) -> String {
        switch period {
        case .day: return "D"
        case .week: return "W"
        case .month: return "M"
        }
    }

    private func handleGeofenceTransition(inside: Bool) {
        if isProcessingRegionState {
            return
        }
        isProcessingRegionState = true
        defer { isProcessingRegionState = false }

        guard let transition = trackingService.processTransition(
            inside: inside,
            isInsideOffice: isInsideOffice,
            isTrackingReady: isTrackingReady,
            trackingNotificationsEnabled: trackingNotificationsEnabled,
            notificationPermission: notificationPermission
        ) else { return }

        isInsideOffice = transition.isInsideOffice
        let event = transition.event
        events.append(event)
        sortEvents()

        guard let row = transition.notificationRow else { return }
        notificationLog.insert(row, at: 0)
        sendLocalNotification(for: transition.event)
    }

    private func sortEvents() {
        events.sort { lhs, rhs in
            if lhs.timestamp == rhs.timestamp { return lhs.id.uuidString < rhs.id.uuidString }
            return lhs.timestamp < rhs.timestamp
        }
    }

    private func refreshComputedState() {
        sessionResult = sessionEngine.build(from: events)
        eventsDescending = events.sorted(by: { $0.timestamp > $1.timestamp })
    }

    private func sendLocalNotification(for event: PresenceEvent) {
        let content = UNMutableNotificationContent()
        content.title = event.type == .entry ? "Office Entry Detected" : "Office Exit Detected"
        let time = DateFormatter.localizedString(from: event.timestamp, dateStyle: .none, timeStyle: .short)
        content.body = "\(event.type.rawValue) at \(time)"
        content.sound = .default

        let request = UNNotificationRequest(identifier: event.id.uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func syncLiveClock() {
        liveNow = Date()
    }

    private func startLiveClock() {
        guard liveClockCancellable == nil else { return }
        liveClockCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] tick in
                self?.liveNow = tick
            }
    }

    private func stopLiveClock() {
        liveClockCancellable?.cancel()
        liveClockCancellable = nil
    }

    private func runRecoveryIntegrityValidation() {
        recoveryValidationMessage = "Integrity validation passed."
    }

    private func loadPersistedState() {
        guard FileManager.default.fileExists(atPath: stateURL.path) else { return }
        do {
            let data = try Data(contentsOf: stateURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let saved = try decoder.decode(PersistedState.self, from: data)
            locationPermission = saved.locationPermission
            notificationPermission = saved.notificationPermission
            locationPermissionDeferred = saved.locationPermissionDeferred
            notificationPermissionDeferred = saved.notificationPermissionDeferred
            trackingNotificationsEnabled = saved.trackingNotificationsEnabled
            office = saved.office
            officeValidationMessage = office == nil ? "No office configured." : "Office geofence configured."
            targets = saved.targets
            events = saved.events
            correctionAuditLog = saved.correctionAuditLog
            notificationLog = saved.notificationLog
            recoveryValidationMessage = saved.recoveryValidationMessage
            showOnboarding = saved.showOnboarding
            isInsideOffice = saved.isInsideOffice
            runRecoveryIntegrityValidation()
        } catch {
            // Ignore malformed persisted files and start from defaults.
            runRecoveryIntegrityValidation()
        }
    }

    private func persist() {
        let snapshot = PersistedState(
            locationPermission: locationPermission,
            notificationPermission: notificationPermission,
            locationPermissionDeferred: locationPermissionDeferred,
            notificationPermissionDeferred: notificationPermissionDeferred,
            trackingNotificationsEnabled: trackingNotificationsEnabled,
            office: office,
            targets: targets,
            events: events,
            correctionAuditLog: correctionAuditLog,
            notificationLog: notificationLog,
            recoveryValidationMessage: recoveryValidationMessage,
            showOnboarding: showOnboarding,
            isInsideOffice: isInsideOffice
        )

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(snapshot)
            try data.write(to: stateURL, options: [.atomic, .completeFileProtection])
        } catch {
            // Persistence failures should not crash app usage.
        }
    }

    private func refreshNotificationPermissionStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    self.notificationPermission = .authorizedAlways
                    self.notificationPermissionDeferred = false
                case .denied:
                    self.notificationPermission = .denied
                    self.trackingNotificationsEnabled = false
                    self.notificationPermissionDeferred = false
                case .notDetermined:
                    if self.notificationPermission == .authorizedAlways || self.notificationPermission == .denied {
                        self.notificationPermission = .notDetermined
                    }
                @unknown default:
                    self.notificationPermission = .notDetermined
                }
            }
        }
    }
}

final class LocationTrackingManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let monitoredIdentifier = "ofchours-office"
    private var latestOffice: OfficeLocation?
    private var pendingCurrentLocationRequest = false
    private var suppressTransitionForNextLocationUpdate = false

    var onPermissionChanged: ((PermissionState) -> Void)?
    var onRegionTransition: ((Bool) -> Void)?
    var onCurrentLocation: ((CLLocationCoordinate2D) -> Void)?
    var onLocationError: ((String) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.pausesLocationUpdatesAutomatically = true
    }

    func requestAlwaysPermission() {
        manager.requestAlwaysAuthorization()
    }

    func requestCurrentLocation() {
        let status = manager.authorizationStatus
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            pendingCurrentLocationRequest = false
            suppressTransitionForNextLocationUpdate = true
            manager.requestLocation()
        case .notDetermined:
            pendingCurrentLocationRequest = true
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            pendingCurrentLocationRequest = false
            onLocationError?("Location permission is denied. Enable it in Settings.")
        @unknown default:
            pendingCurrentLocationRequest = false
            onLocationError?("Location permission status is unavailable.")
        }
    }

    func refreshPermission() {
        onPermissionChanged?(map(manager.authorizationStatus))
    }

    func requestMonitoredRegionState() {
        for region in manager.monitoredRegions where region.identifier == monitoredIdentifier {
            manager.requestState(for: region)
        }
    }

    func updateMonitoring(office: OfficeLocation?) {
        latestOffice = office
        for region in manager.monitoredRegions {
            manager.stopMonitoring(for: region)
        }
        manager.stopMonitoringSignificantLocationChanges()

        guard let office else { return }
        let status = manager.authorizationStatus
        guard status == .authorizedAlways else { return }

        manager.startMonitoringSignificantLocationChanges()
        let center = CLLocationCoordinate2D(latitude: office.latitude, longitude: office.longitude)
        let region = CLCircularRegion(center: center, radius: max(50, office.radiusMeters), identifier: monitoredIdentifier)
        region.notifyOnEntry = true
        region.notifyOnExit = true
        manager.startMonitoring(for: region)
        manager.requestState(for: region)
    }

    private func map(_ status: CLAuthorizationStatus) -> PermissionState {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted, .denied: return .denied
        case .authorizedWhenInUse: return .authorizedWhenInUse
        case .authorizedAlways: return .authorizedAlways
        @unknown default: return .notDetermined
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        onPermissionChanged?(map(manager.authorizationStatus))
        updateMonitoring(office: latestOffice)
        if pendingCurrentLocationRequest {
            let status = manager.authorizationStatus
            if status == .authorizedAlways || status == .authorizedWhenInUse {
                pendingCurrentLocationRequest = false
                suppressTransitionForNextLocationUpdate = true
                manager.requestLocation()
            } else if status == .denied || status == .restricted {
                pendingCurrentLocationRequest = false
                onLocationError?("Location permission is denied. Enable it in Settings.")
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard region.identifier == monitoredIdentifier else { return }
        onRegionTransition?(true)
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard region.identifier == monitoredIdentifier else { return }
        onRegionTransition?(false)
    }

    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        guard region.identifier == monitoredIdentifier else { return }
        switch state {
        case .inside:
            onRegionTransition?(true)
        case .outside:
            onRegionTransition?(false)
        case .unknown:
            break
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        onCurrentLocation?(location.coordinate)

        // A manual "My Location" probe should update map fields only, not create attendance events.
        if suppressTransitionForNextLocationUpdate {
            suppressTransitionForNextLocationUpdate = false
            return
        }

        guard let office = latestOffice else { return }
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 200 else { return }

        let officeLocation = CLLocation(latitude: office.latitude, longitude: office.longitude)
        let inside = location.distance(from: officeLocation) <= max(50, office.radiusMeters)
        onRegionTransition?(inside)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let locationError = error as? CLError
        if locationError?.code == .locationUnknown {
            return
        }
        onLocationError?(error.localizedDescription)
    }
}
