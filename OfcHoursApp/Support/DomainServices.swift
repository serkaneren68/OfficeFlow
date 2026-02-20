import Foundation

struct TrackingTransitionResult {
    var isInsideOffice: Bool
    var event: PresenceEvent
    var notificationRow: String?
}

struct TrackingService {
    func processTransition(
        inside: Bool,
        isInsideOffice: Bool,
        isTrackingReady: Bool,
        trackingNotificationsEnabled: Bool,
        notificationPermission: PermissionState,
        now: Date = Date()
    ) -> TrackingTransitionResult? {
        guard isTrackingReady else { return nil }
        guard inside != isInsideOffice else { return nil }

        let type: PresenceEventType = inside ? .entry : .exit
        let event = PresenceEvent(timestamp: now, type: type, source: .geofence, manualReason: nil)

        let notificationRow: String?
        if trackingNotificationsEnabled, notificationPermission == .authorizedAlways {
            let time = DateFormatter.localizedString(from: event.timestamp, dateStyle: .none, timeStyle: .short)
            notificationRow = "\(type.rawValue) detected at \(time)"
        } else {
            notificationRow = nil
        }

        return TrackingTransitionResult(
            isInsideOffice: inside,
            event: event,
            notificationRow: notificationRow
        )
    }
}

struct SessionEngine {
    func build(from events: [PresenceEvent]) -> SessionBuildResult {
        let sorted = events.sorted { lhs, rhs in
            if lhs.timestamp == rhs.timestamp { return lhs.id.uuidString < rhs.id.uuidString }
            return lhs.timestamp < rhs.timestamp
        }

        var sessions: [AttendanceSession] = []
        var openEntry: PresenceEvent?

        for event in sorted {
            switch event.type {
            case .entry:
                openEntry = event
            case .exit:
                guard let start = openEntry else { continue }
                if event.timestamp >= start.timestamp {
                    sessions.append(AttendanceSession(start: start.timestamp, end: event.timestamp))
                }
                openEntry = nil
            }
        }

        return SessionBuildResult(sessions: sessions)
    }
}

struct ReportingService {
    func trackedMinutes(sessions: [AttendanceSession], for period: ReportPeriod, at date: Date) -> Int {
        let cal = Calendar.current
        let range: DateInterval

        switch period {
        case .day:
            let start = cal.startOfDay(for: date)
            let end = cal.date(byAdding: .day, value: 1, to: start) ?? date
            range = DateInterval(start: start, end: end)
        case .week:
            guard let week = cal.dateInterval(of: .weekOfYear, for: date) else { return 0 }
            range = week
        case .month:
            guard let month = cal.dateInterval(of: .month, for: date) else { return 0 }
            range = month
        }

        return sessions.reduce(0) { partial, session in
            let overlapStart = max(session.start, range.start)
            let overlapEnd = min(session.end, range.end)
            guard overlapEnd > overlapStart else { return partial }
            return partial + Int(overlapEnd.timeIntervalSince(overlapStart) / 60.0)
        }
    }

    func targetHours(for period: ReportPeriod, targets: TargetPolicy) -> Int {
        switch period {
        case .day: return targets.dailyHours
        case .week: return targets.weeklyHours
        case .month: return targets.monthlyHours
        }
    }

    func progressLabel(sessions: [AttendanceSession], for period: ReportPeriod, at date: Date, targets: TargetPolicy) -> String {
        let minutes = trackedMinutes(sessions: sessions, for: period, at: date)
        let targetHoursValue = targetHours(for: period, targets: targets)
        let targetMinutes = targetHoursValue * 60
        let variance = minutes - targetMinutes
        let sign = variance >= 0 ? "+" : ""
        return "\(String(format: "%.1f", Double(minutes)/60.0))h / \(targetHoursValue)h (\(sign)\(String(format: "%.1f", Double(variance)/60.0))h)"
    }
}

struct CorrectionService {
    func addManualEvent(type: PresenceEventType, timestamp: Date, reason: String) -> (event: PresenceEvent, audit: CorrectionAuditEntry) {
        let cleanReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        let event = PresenceEvent(timestamp: timestamp, type: type, source: .manual, manualReason: cleanReason)
        let audit = CorrectionAuditEntry(
            timestamp: Date(),
            action: .add,
            eventID: event.id,
            reason: cleanReason.isEmpty ? "No reason provided" : cleanReason
        )
        return (event, audit)
    }

    func updateEvent(
        events: [PresenceEvent],
        id: UUID,
        type: PresenceEventType,
        timestamp: Date,
        reason: String
    ) -> (events: [PresenceEvent], audit: CorrectionAuditEntry)? {
        guard let index = events.firstIndex(where: { $0.id == id }) else { return nil }
        let cleanReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)

        var updatedEvents = events
        updatedEvents[index].type = type
        updatedEvents[index].timestamp = timestamp
        updatedEvents[index].source = .manual
        updatedEvents[index].manualReason = cleanReason

        let audit = CorrectionAuditEntry(
            timestamp: Date(),
            action: .edit,
            eventID: id,
            reason: cleanReason.isEmpty ? "No reason provided" : cleanReason
        )
        return (updatedEvents, audit)
    }

    func deleteEvent(events: [PresenceEvent], id: UUID, reason: String) -> (events: [PresenceEvent], audit: CorrectionAuditEntry) {
        let cleanReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        let updatedEvents = events.filter { $0.id != id }
        let audit = CorrectionAuditEntry(
            timestamp: Date(),
            action: .delete,
            eventID: id,
            reason: cleanReason.isEmpty ? "No reason provided" : cleanReason
        )
        return (updatedEvents, audit)
    }
}
