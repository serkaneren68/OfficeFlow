import SwiftUI

struct TimelineView: View {
    @EnvironmentObject private var state: AppState
    @State private var showingAddSheet = false
    @State private var addType: PresenceEventType = .entry
    @State private var addDate: Date = .now
    @State private var addReason: String = ""

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
                addType = .entry
                addDate = .now
                addReason = ""
                showingAddSheet = true
            } label: {
                Label("Add Manual Event", systemImage: "plus.circle.fill")
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
                        Text(event.type.rawValue)
                            .font(AppTypography.body(14))
                            .foregroundStyle(AppPalette.textPrimary)
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
                        Text("\(item.action.rawValue.uppercased()) • \(item.timestamp.formatted(date: .abbreviated, time: .shortened))")
                            .font(AppTypography.mono(12))
                            .foregroundStyle(AppPalette.neonCyan)
                        Text(item.reason)
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
                Picker("Type", selection: $addType) {
                    ForEach(PresenceEventType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                DatePicker("Time", selection: $addDate)
                TextField("Reason", text: $addReason)
            }
            .navigationTitle("Add Event")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingAddSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        state.addManualEvent(type: addType, timestamp: addDate, reason: addReason)
                        showingAddSheet = false
                    }
                    .disabled(addReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func editSheet(event: PresenceEvent) -> some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $editType) {
                    ForEach(PresenceEventType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
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
        Text(text.uppercased())
            .font(AppTypography.mono(12))
            .foregroundStyle(AppPalette.neonCyan)
    }

    private func badge(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
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
}
