import SwiftUI
import SwiftData

struct FeelingsSection: View {
    @Bindable var log: DailyLog
    let settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @State private var pendingNoteType: FeelingType?
    @State private var noteText = ""
    @State private var showCustom = false
    @State private var customFeeling = ""

    var body: some View {
        SectionCard(
            title: "Feelings & Cravings",
            systemImage: "heart.text.square",
            isCollapsed: settings.sectionCollapsedBinding(.feelings, context: modelContext),
            collapsedMessage: DaySectionID.feelings.collapsedMessage
        ) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(FeelingType.allCases) { type in
                    Button {
                        quickLog(type.rawValue)
                    } label: {
                        Label(type.rawValue, systemImage: type.systemImage)
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.accentColor.opacity(0.12))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Log with note…") {
                            pendingNoteType = type
                            noteText = ""
                        }
                    }
                }
            }

            Button {
                customFeeling = ""
                showCustom = true
            } label: {
                Label("Something else…", systemImage: "plus.bubble")
                    .font(.caption.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)

            if log.sortedFeelings.isEmpty {
                Text("Tap a feeling to log it with the current time.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(log.sortedFeelings, id: \.id) { feeling in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(feeling.type) at \(DateHelpers.formattedTime(feeling.timeLogged))")
                                    .font(.subheadline.weight(.medium))
                                if !feeling.note.isEmpty {
                                    Text(feeling.note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button(role: .destructive) {
                                log.feelingEntries.removeAll { $0.id == feeling.id }
                                modelContext.delete(feeling)
                                try? modelContext.save()
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                            }
                        }
                        .padding(.vertical, 8)
                        Divider()
                    }
                }
            }
        }
        .alert("Add a note", isPresented: Binding(
            get: { pendingNoteType != nil },
            set: { if !$0 { pendingNoteType = nil } }
        )) {
            TextField("Optional note", text: $noteText)
            Button("Save") {
                if let type = pendingNoteType {
                    add(type.rawValue, note: noteText)
                }
                pendingNoteType = nil
            }
            Button("Cancel", role: .cancel) { pendingNoteType = nil }
        }
        .alert("Something else", isPresented: $showCustom) {
            TextField("Feeling / craving", text: $customFeeling)
                .onChange(of: customFeeling) { _, newValue in
                    if newValue.count > AppLimits.customFeelingMaxChars {
                        customFeeling = String(newValue.prefix(AppLimits.customFeelingMaxChars))
                    }
                }
            Button("Save") {
                let trimmed = customFeeling.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                add(trimmed, note: "")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Keep it short (\(AppLimits.customFeelingMaxChars) characters max).")
        }
    }

    private func quickLog(_ type: String) {
        add(type, note: "")
    }

    private func add(_ type: String, note: String) {
        let entry = FeelingEntry(type: type, note: note)
        modelContext.insert(entry)
        log.feelingEntries.append(entry)
        try? modelContext.save()
    }
}
