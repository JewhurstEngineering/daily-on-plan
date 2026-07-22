import SwiftUI
import SwiftData

struct BathroomSection: View {
    @Bindable var log: DailyLog
    @Bindable var settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accentPrimary) private var accentPrimary

    @State private var pendingNoteEventID: UUID?
    @State private var noteDraft = ""
    @State private var editTimeEventID: UUID?
    @FocusState private var noteFocused: Bool

    var body: some View {
        SectionCard(
            title: "Bathroom",
            systemImage: "toilet.fill",
            isCollapsed: settings.sectionCollapsedBinding(.bathroom, context: modelContext),
            collapsedMessage: DaySectionID.bathroom.collapsedMessage
        ) {
            Text("Urination · \(log.urineCount)  ·  Bowel · \(log.stoolCount)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button {
                    logEvent(.urine)
                } label: {
                    bathroomActionCard(
                        title: "Urination",
                        subtitle: "Log now",
                        systemImage: "drop.fill",
                        tint: Color.accentColor
                    )
                }
                .buttonStyle(.plain)

                Button {
                    logEvent(.stool)
                } label: {
                    bathroomActionCard(
                        title: "Bowel movement",
                        subtitle: "Log now",
                        systemImage: "toilet.fill",
                        tint: Color(hex: "#8B5E3C")
                    )
                }
                .buttonStyle(.plain)
            }

            Text("Tap to log now. You can add an optional note right after.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if log.bathroomEvents.isEmpty {
                Text("No entries yet today.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(log.bathroomEvents.reversed()) { event in
                        HStack(alignment: .top) {
                            Image(systemName: event.kind == .urine ? "drop.fill" : "toilet.fill")
                                .font(.title3)
                                .foregroundStyle(event.kind == .urine ? Color.accentColor : Color(hex: "#8B5E3C"))
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.kind.title)
                                    .font(.subheadline.weight(.semibold))
                                Button(DateHelpers.formattedTime(event.timeLogged)) {
                                    editTimeEventID = event.id
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(accentPrimary)
                                .buttonStyle(.plain)
                                if !event.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text(event.note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 8)
                            Button {
                                pendingNoteEventID = event.id
                                noteDraft = event.note
                            } label: {
                                Image(systemName: event.note.isEmpty ? "note.text.badge.plus" : "note.text")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(event.note.isEmpty ? "Add note" : "Edit note")

                            Button(role: .destructive) {
                                log.removeBathroomEvent(id: event.id)
                                try? modelContext.save()
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Delete \(event.kind.title)")
                        }
                        .padding(.vertical, 6)
                        Divider()
                    }
                }
            }
        }
        .sheet(item: pendingNoteBinding) { event in
            NavigationStack {
                Form {
                    Section {
                        Text(event.kind.title)
                            .font(.subheadline.weight(.semibold))
                        Text(DateHelpers.formattedTime(event.timeLogged))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Optional note", text: $noteDraft, axis: .vertical)
                            .lineLimit(3...6)
                            .focused($noteFocused)
                    } footer: {
                        Text("Notes stay on this device and in your exports. Skip if you don’t need one.")
                    }
                }
                .navigationTitle("Note")
                .navigationBarTitleDisplayMode(.inline)
                .keyboardDoneToolbar(focus: $noteFocused)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Skip") {
                            pendingNoteEventID = nil
                            noteDraft = ""
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            log.updateBathroomEventNote(
                                id: event.id,
                                note: noteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                            try? modelContext.save()
                            pendingNoteEventID = nil
                            noteDraft = ""
                        }
                    }
                }
                .onAppear { noteFocused = true }
            }
            .presentationDetents([.medium])
        }
        .sheet(item: editTimeBinding) { event in
            EditTimestampSheet(
                title: event.kind.title,
                initialDate: event.timeLogged,
                includesDate: true
            ) { newDate in
                moveBathroomEvent(id: event.id, to: newDate)
                editTimeEventID = nil
            }
        }
    }

    private func bathroomActionCard(title: String, subtitle: String, systemImage: String, tint: Color) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: 64, height: 64)
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(tint)
            }
            VStack(spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(tint.opacity(0.25), lineWidth: 1)
        )
    }

    private var pendingNoteBinding: Binding<BathroomEventRecord?> {
        Binding(
            get: {
                guard let id = pendingNoteEventID else { return nil }
                return log.bathroomEvents.first { $0.id == id }
            },
            set: { newValue in
                pendingNoteEventID = newValue?.id
                if newValue == nil { noteDraft = "" }
            }
        )
    }

    private var editTimeBinding: Binding<BathroomEventRecord?> {
        Binding(
            get: {
                guard let id = editTimeEventID else { return nil }
                return log.bathroomEvents.first { $0.id == id }
            },
            set: { if $0 == nil { editTimeEventID = nil } }
        )
    }

    private func logEvent(_ kind: BathroomKind) {
        let event = log.addBathroomEvent(kind: kind)
        try? modelContext.save()
        pendingNoteEventID = event.id
        noteDraft = ""
    }

    private func moveBathroomEvent(id: UUID, to newDate: Date) {
        let targetDay = DateHelpers.startOfDay(newDate)
        let sourceDay = DateHelpers.startOfDay(log.date)
        if targetDay == sourceDay {
            log.updateBathroomEventTime(id: id, timeLogged: newDate)
        } else if var event = log.takeBathroomEvent(id: id) {
            event.timeLogged = newDate
            let targetLog = DataStore.log(for: targetDay, in: modelContext, defaultGoal: settings.defaultProteinGoal)
            targetLog.insertBathroomEvent(event)
        }
        try? modelContext.save()
    }
}
