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
}

enum PresenceEventType: String, Codable, CaseIterable {
    case entry = "Entry"
    case exit = "Exit"
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
}
