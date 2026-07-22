import SwiftUI
import SwiftData

struct FeelingsSection: View {
    @Bindable var log: DailyLog
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accentPrimary) private var accentPrimary
    @AppStorage("feelings.lastCategory") private var lastCategoryRaw = FeelingCategory.energy.rawValue

    @State private var selectedCategory: FeelingCategory = .energy
    @State private var customText = ""
    @State private var showCustom = false
    @State private var noteTarget: FeelingEntry?
    @State private var noteText = ""
    @State private var intensityTarget: FeelingType?
    @State private var editTarget: FeelingEntry?

    private var chips: [FeelingType] {
        FeelingType.items(in: selectedCategory)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Feelings & Cravings")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(FeelingCategory.allCases) { category in
                        Button {
                            selectedCategory = category
                            lastCategoryRaw = category.rawValue
                        } label: {
                            Text(category.rawValue)
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedCategory == category ? accentPrimary.opacity(0.18) : Color(.secondarySystemBackground))
                                .foregroundStyle(selectedCategory == category ? accentPrimary : .primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 8)], spacing: 8) {
                ForEach(chips) { type in
                    Button {
                        if type.needsIntensity {
                            intensityTarget = type
                        } else {
                            addFeeling(type.displayType(intensity: nil))
                        }
                    } label: {
                        Label(type.rawValue, systemImage: type.systemImage)
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 6)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                            if type.needsIntensity {
                                intensityTarget = type
                            } else {
                                let entry = FeelingEntry(type: type.rawValue, note: "", timeLogged: Date())
                                modelContext.insert(entry)
                                log.feelingEntries.append(entry)
                                try? modelContext.save()
                                noteTarget = entry
                                noteText = ""
                            }
                        }
                    )
                }
            }

            Button("Something else…") {
                showCustom = true
            }
            .buttonStyle(.bordered)

            if !log.feelingEntries.isEmpty {
                Divider()
                ForEach(log.sortedFeelings.reversed(), id: \.id) { entry in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.type)
                            if !entry.note.isEmpty {
                                Text(entry.note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button(DateHelpers.formattedTime(entry.timeLogged)) {
                            editTarget = entry
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accentPrimary)
                        .buttonStyle(.plain)
                        Button(role: .destructive) {
                            log.feelingEntries.removeAll { $0.id == entry.id }
                            modelContext.delete(entry)
                            try? modelContext.save()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                    .contentShape(Rectangle())
                    .onLongPressGesture {
                        noteTarget = entry
                        noteText = entry.note
                    }
                }
            }
        }
        .onAppear {
            if let category = FeelingCategory(rawValue: lastCategoryRaw) {
                selectedCategory = category
            }
        }
        .alert("Add note", isPresented: Binding(
            get: { noteTarget != nil },
            set: { if !$0 { noteTarget = nil } }
        )) {
            TextField("Optional note", text: $noteText)
            Button("Save") {
                noteTarget?.note = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
                try? modelContext.save()
                noteTarget = nil
            }
            Button("Cancel", role: .cancel) { noteTarget = nil }
        }
        .alert("Something else", isPresented: $showCustom) {
            TextField("Describe the feeling", text: $customText)
            Button("Log") {
                let value = customText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !value.isEmpty else { return }
                addFeeling(value)
                customText = ""
            }
            Button("Cancel", role: .cancel) { customText = "" }
        }
        .confirmationDialog("Hunger pang intensity", isPresented: Binding(
            get: { intensityTarget != nil },
            set: { if !$0 { intensityTarget = nil } }
        ), titleVisibility: .visible) {
            ForEach(FeelingIntensity.allCases) { intensity in
                Button(intensity.label) {
                    if let type = intensityTarget {
                        addFeeling(type.displayType(intensity: intensity))
                    }
                    intensityTarget = nil
                }
            }
            Button("Cancel", role: .cancel) { intensityTarget = nil }
        } message: {
            Text("How strong is the hunger pang?")
        }
        .sheet(item: $editTarget) { entry in
            EditTimestampSheet(
                title: entry.type,
                initialDate: entry.timeLogged,
                includesDate: true
            ) { newDate in
                moveFeeling(entry, to: newDate)
            }
        }
    }

    private func addFeeling(_ type: String) {
        let entry = FeelingEntry(type: type, note: "", timeLogged: Date())
        modelContext.insert(entry)
        log.feelingEntries.append(entry)
        try? modelContext.save()
    }

    private func moveFeeling(_ entry: FeelingEntry, to newDate: Date) {
        let settings = DataStore.settings(in: modelContext)
        let targetDay = DateHelpers.startOfDay(newDate)
        let sourceDay = DateHelpers.startOfDay(log.date)
        entry.timeLogged = newDate
        if targetDay != sourceDay {
            log.feelingEntries.removeAll { $0.id == entry.id }
            let targetLog = DataStore.log(for: targetDay, in: modelContext, defaultGoal: settings.defaultProteinGoal)
            targetLog.feelingEntries.append(entry)
        }
        try? modelContext.save()
    }
}

extension FeelingEntry: @retroactive Identifiable {}
