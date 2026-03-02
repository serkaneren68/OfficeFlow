import SwiftUI

struct TimelineView: View {
    @EnvironmentObject private var state: AppState
    @State private var showingAddSheet = false
    @State private var addMode: ManualAddMode = .singleEvent
    @State private var addSingleType: PresenceEventType = .entry
    @State private var addSingleDate: Date = .now
    @State private var addEntryDate: Date = .now
    @State private var addExitDate: Date = .now
    @State private var addReason: String = ""
    @State private var addValidationMessage: String = ""

    @State private var editingEvent: PresenceEvent?
    @State private var editType: PresenceEventType = .entry
    @State private var editDate: Date = .now
    @State private var editReason: String = ""
    @State private var reveal = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        heroCard
                            .offset(y: reveal ? 0 : 10)
                            .opacity(reveal ? 1 : 0)

                        sessionsCard
                            .offset(y: reveal ? 0 : 18)
                            .opacity(reveal ? 1 : 0)

                        eventsCard
                            .offset(y: reveal ? 0 : 26)
                            .opacity(reveal ? 1 : 0)

                        auditCard
                            .offset(y: reveal ? 0 : 34)
                            .opacity(reveal ? 1 : 0)
                    }
                    .padding()
                    .animation(.easeOut(duration: 0.45), value: reveal)
                }
            }
            .navigationTitle("Timeline")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear { reveal = true }
            .sheet(isPresented: $showingAddSheet) { addSheet }
            .sheet(item: $editingEvent) { event in
                editSheet(event: event)
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ATTENDANCE TIMELINE")
                .font(AppTypography.mono(12))
                .foregroundStyle(AppPalette.neonCyan)

            HStack(spacing: 10) {
                badge(title: "Events", value: "\(state.eventsDescending.count)", color: AppPalette.neonCyan)
                badge(title: "Sessions", value: "\(state.sessionResult.sessions.count)", color: AppPalette.neonMint)
                badge(title: "Corrections", value: "\(state.correctionAuditLog.count)", color: AppPalette.neonAmber)
            }

            Button {
                let now = Date()
                addMode = .singleEvent
                addSingleType = state.isCurrentlyInOffice ? .exit : .entry
                addSingleDate = now
                addExitDate = now
                addEntryDate = Calendar.current.date(byAdding: .hour, value: -8, to: now) ?? now
                addReason = ""
                addValidationMessage = ""
                showingAddSheet = true
            } label: {
                Label("Add Manual Record", systemImage: "plus.circle.fill")
                    .font(AppTypography.heading(16))
                    .foregroundStyle(AppPalette.bgEnd)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppPalette.neonCyan)
                    )
            }
            .buttonStyle(.plain)
        }
        .neonCard()
    }

    private var sessionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Sessions")
            if state.sessionResult.sessions.isEmpty {
                Text("No complete sessions yet.")
                    .font(AppTypography.body(14))
                    .foregroundStyle(AppPalette.textSecondary)
            } else {
                ForEach(state.sessionResult.sessions.suffix(6).reversed()) { session in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(session.start.formatted(date: .abbreviated, time: .shortened))")
                                .font(AppTypography.body(14))
                                .foregroundStyle(AppPalette.textPrimary)
                            Text("to \(session.end.formatted(date: .omitted, time: .shortened))")
                                .font(AppTypography.mono(11))
                                .foregroundStyle(AppPalette.textSecondary)
                        }
                        Spacer()
                        Text("\(session.minutes)m")
                            .font(AppTypography.heading(15))
                            .foregroundStyle(AppPalette.neonMint)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppPalette.panelSoft.opacity(0.8))
                    )
                }
            }
        }
        .neonCard()
    }

    private var eventsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Events")
            if state.eventsDescending.isEmpty {
                Text("No event detected yet.")
                    .font(AppTypography.body(14))
                    .foregroundStyle(AppPalette.textSecondary)
            } else {
                ForEach(state.eventsDescending.prefix(20)) { event in
                    HStack {
                        Circle()
                            .fill(event.type == .entry ? AppPalette.neonMint : AppPalette.neonAmber)
                            .frame(width: 8, height: 8)
                        Text(event.type.localizedTitle)
                            .font(AppTypography.body(14))
                            .foregroundStyle(AppPalette.textPrimary)
                        if event.source == .manual {
                            Text(AppLocalization.text("event.manualTag", fallback: "MANUAL"))
                                .font(AppTypography.mono(9))
                                .foregroundStyle(AppPalette.neonMint)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(AppPalette.neonMint.opacity(0.15))
                                )
                        }
                        Spacer()
                        Text(event.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(AppTypography.mono(12))
                            .foregroundStyle(AppPalette.textSecondary)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingEvent = event
                        editType = event.type
                        editDate = event.timestamp
                        editReason = event.manualReason ?? ""
                    }
                }
            }
        }
        .neonCard()
    }

    private var auditCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Correction Audit")
            if state.correctionAuditLog.isEmpty {
                Text("No manual correction.")
                    .font(AppTypography.body(14))
                    .foregroundStyle(AppPalette.textSecondary)
            } else {
                ForEach(state.correctionAuditLog.prefix(8)) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(item.action.localizedTitle.uppercased()) • \(item.timestamp.formatted(date: .abbreviated, time: .shortened))")
                            .font(AppTypography.mono(12))
                            .foregroundStyle(AppPalette.neonCyan)
                        Text(auditReasonText(item.reason))
                            .font(AppTypography.body(13))
                            .foregroundStyle(AppPalette.textSecondary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppPalette.panelSoft.opacity(0.75))
                    )
                }
            }
        }
        .neonCard()
    }

    private var addSheet: some View {
        NavigationStack {
            Form {
                Picker("Add Mode", selection: $addMode) {
                    ForEach(ManualAddMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if addMode == .singleEvent {
                    Picker("Type", selection: $addSingleType) {
                        ForEach(PresenceEventType.allCases, id: \.self) { type in
                            Text(type.localizedTitle).tag(type)
                        }
                    }
                    DatePicker("Time", selection: $addSingleDate)
                } else {
                    DatePicker("Entry Time", selection: $addEntryDate)
                    DatePicker("Exit Time", selection: $addExitDate, in: addEntryDate...)
                }

                TextField("Reason (optional)", text: $addReason)
                if !addValidationMessage.isEmpty {
                    Text(addValidationMessage)
                        .font(AppTypography.body(12))
                        .foregroundStyle(AppPalette.neonRed)
                }
            }
            .onChange(of: addEntryDate) { _, newValue in
                if addExitDate < newValue {
                    addExitDate = newValue
                }
            }
            .onChange(of: addMode) { _, _ in
                addValidationMessage = ""
            }
            .navigationTitle("Add Manual Record")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingAddSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if saveManualRecord() {
                            showingAddSheet = false
                        }
                    }
                }
            }
        }
    }

    private func editSheet(event: PresenceEvent) -> some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $editType) {
                    ForEach(PresenceEventType.allCases, id: \.self) { type in
                        Text(type.localizedTitle).tag(type)
                    }
                }
                DatePicker("Time", selection: $editDate)
                TextField("Reason", text: $editReason)
                Button("Delete Event", role: .destructive) {
                    state.deleteEvent(id: event.id, reason: editReason)
                    editingEvent = nil
                }
                .disabled(editReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .navigationTitle("Edit Event")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { editingEvent = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        state.updateEvent(id: event.id, type: editType, timestamp: editDate, reason: editReason)
                        editingEvent = nil
                    }
                    .disabled(editReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(AppLocalization.text(text, fallback: text).uppercased())
            .font(AppTypography.mono(12))
            .foregroundStyle(AppPalette.neonCyan)
    }

    private func badge(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(AppLocalization.text(title, fallback: title).uppercased())
                .font(AppTypography.mono(10))
                .foregroundStyle(AppPalette.textSecondary)
            Text(value)
                .font(AppTypography.heading(16))
                .foregroundStyle(color)
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

    private func auditReasonText(_ value: String) -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized == correctionNoReasonToken.lowercased() ||
            normalized == "no reason provided" ||
            normalized == "neden belirtilmedi" {
            return AppLocalization.text("correction.noReason", fallback: "No reason provided")
        }
        return value
    }

    private func saveManualRecord() -> Bool {
        addValidationMessage = ""
        switch addMode {
        case .singleEvent:
            state.addManualEvent(type: addSingleType, timestamp: addSingleDate, reason: addReason)
            return true
        case .session:
            guard state.addManualSession(entry: addEntryDate, exit: addExitDate, reason: addReason) else {
                addValidationMessage = AppLocalization.text(
                    "timeline.manualSession.invalid",
                    fallback: "Exit time must be later than or equal to entry time."
                )
                return false
            }
            return true
        }
    }
}

private enum ManualAddMode: CaseIterable {
    case singleEvent
    case session

    var title: String {
        switch self {
        case .singleEvent:
            return AppLocalization.text("timeline.addMode.single", fallback: "Single Event")
        case .session:
            return AppLocalization.text("timeline.addMode.session", fallback: "Session")
        }
    }
}
