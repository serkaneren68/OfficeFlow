import Foundation

enum PermissionState: String, CaseIterable, Codable {
    case notDetermined = "Not Determined"
    case authorizedWhenInUse = "Authorized (When In Use)"
    case authorizedAlways = "Authorized (Always)"
    case denied = "Denied"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case PermissionState.notDetermined.rawValue:
            self = .notDetermined
        case PermissionState.authorizedWhenInUse.rawValue:
            self = .authorizedWhenInUse
        case PermissionState.authorizedAlways.rawValue:
            self = .authorizedAlways
        case PermissionState.denied.rawValue:
            self = .denied
        case "Authorized":
            self = .authorizedAlways
        case "Deferred":
            self = .notDetermined
        default:
            self = .notDetermined
        }
    }

    var localizedTitle: String {
        switch self {
        case .notDetermined:
            return AppLocalization.text("permission.notDetermined", fallback: "Not Determined")
        case .authorizedWhenInUse:
            return AppLocalization.text("permission.authorizedWhenInUse", fallback: "Authorized (When In Use)")
        case .authorizedAlways:
            return AppLocalization.text("permission.authorizedAlways", fallback: "Authorized (Always)")
        case .denied:
            return AppLocalization.text("permission.denied", fallback: "Denied")
        }
    }
}

enum PresenceEventType: String, Codable, CaseIterable {
    case entry = "Entry"
    case exit = "Exit"

    var localizedTitle: String {
        switch self {
        case .entry:
            return AppLocalization.text("event.entry", fallback: "Entry")
        case .exit:
            return AppLocalization.text("event.exit", fallback: "Exit")
        }
    }
}

enum EventSource: String, Codable {
    case geofence
    case manual

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case EventSource.geofence.rawValue:
            self = .geofence
        case EventSource.manual.rawValue:
            self = .manual
        default:
            self = .manual
        }
    }
}

struct OfficeLocation: Codable {
    var name: String
    var latitude: Double
    var longitude: Double
    var radiusMeters: Double
}

struct TargetPolicy: Codable {
    var dailyHours: Int
    var weeklyHours: Int
    var monthlyHours: Int
}

struct PresenceEvent: Identifiable, Codable {
    var id: UUID = UUID()
    var timestamp: Date
    var type: PresenceEventType
    var source: EventSource
    var manualReason: String?
}

struct AttendanceSession: Identifiable {
    var id: UUID = UUID()
    var start: Date
    var end: Date

    var minutes: Int {
        max(0, Int(end.timeIntervalSince(start) / 60.0))
    }
}

struct SessionBuildResult {
    var sessions: [AttendanceSession]
}

enum CorrectionAction: String, Codable {
    case add
    case edit
    case delete

    var localizedTitle: String {
        switch self {
        case .add:
            return AppLocalization.text("correction.add", fallback: "Add")
        case .edit:
            return AppLocalization.text("correction.edit", fallback: "Edit")
        case .delete:
            return AppLocalization.text("correction.delete", fallback: "Delete")
        }
    }
}

struct CorrectionAuditEntry: Identifiable, Codable {
    var id: UUID = UUID()
    var timestamp: Date
    var action: CorrectionAction
    var eventID: UUID
    var reason: String
}

enum ReportPeriod: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"

    var localizedTitle: String {
        switch self {
        case .day:
            return AppLocalization.text("period.day", fallback: "Day")
        case .week:
            return AppLocalization.text("period.week", fallback: "Week")
        case .month:
            return AppLocalization.text("period.month", fallback: "Month")
        }
    }
}
