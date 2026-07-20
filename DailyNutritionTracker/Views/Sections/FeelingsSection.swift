import SwiftUI
import SwiftData

struct FeelingsSection: View {
    @Bindable var log: DailyLog
    @Environment(\.modelContext) private var modelContext
    @State private var pendingNoteType: FeelingType?
    @State private var noteText = ""

    var body: some View {
        SectionCard(title: "Feelings & Cravings", systemImage: "heart.text.square") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                ForEach(FeelingType.allCases) { type in
                    Button {
                        quickLog(type)
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

            if log.sortedFeelings.isEmpty {
                Text("Tap a feeling to log it with the current time.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
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
                        .padding(.vertical, 4)
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
                    add(type, note: noteText)
                }
                pendingNoteType = nil
            }
            Button("Cancel", role: .cancel) { pendingNoteType = nil }
        }
    }

    private func quickLog(_ type: FeelingType) {
        add(type, note: "")
    }

    private func add(_ type: FeelingType, note: String) {
        let entry = FeelingEntry(type: type.rawValue, note: note)
        modelContext.insert(entry)
        log.feelingEntries.append(entry)
        try? modelContext.save()
    }
}
