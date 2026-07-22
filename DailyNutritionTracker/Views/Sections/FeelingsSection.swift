import SwiftUI
import SwiftData

struct FeelingsSection: View {
    @Bindable var log: DailyLog
    @Bindable var settings: AppSettings
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
    @State private var showLogList = false

    private var alcoholTrackingEnabled: Bool {
        settings.drinkingMode.showsSection
    }

    private var chips: [FeelingType] {
        FeelingType.items(in: selectedCategory, alcoholTrackingEnabled: alcoholTrackingEnabled)
    }

    private var chipColumns: [GridItem] {
        if chips.count <= 2 {
            return [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        }
        if chips.count == 3 {
            return Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
        }
        return [GridItem(.adaptive(minimum: 100), spacing: 8)]
    }

    var body: some View {
        SectionCard(
            title: "Feelings & Cravings",
            systemImage: "heart.text.square",
            isCollapsed: settings.sectionCollapsedBinding(.feelings, context: modelContext),
            collapsedMessage: log.feelingEntries.isEmpty
                ? DaySectionID.feelings.collapsedMessage
                : "\(log.feelingEntries.count) logged — tap the chevron to show."
        ) {
            // Equal-width pills so all categories fit without scrolling.
            HStack(spacing: 4) {
                ForEach(FeelingCategory.allCases) { category in
                    Button {
                        selectedCategory = category
                        lastCategoryRaw = category.rawValue
                    } label: {
                        Text(category.rawValue)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(selectedCategory == category ? accentPrimary.opacity(0.18) : Color(.secondarySystemBackground))
                            .foregroundStyle(selectedCategory == category ? accentPrimary : .primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            LazyVGrid(columns: chipColumns, alignment: chips.count <= 3 ? .center : .leading, spacing: 8) {
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
                            .multilineTextAlignment(.center)
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
                DisclosureGroup(isExpanded: $showLogList) {
                    VStack(spacing: 0) {
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
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                            .onLongPressGesture {
                                noteTarget = entry
                                noteText = entry.note
                            }
                            Divider()
                        }
                    }
                } label: {
                    Text("Logged today (\(log.feelingEntries.count))")
                        .font(.subheadline.weight(.semibold))
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
        .sheet(item: $intensityTarget) { type in
            FeelingIntensitySheet(type: type) { intensity in
                addFeeling(type.displayType(intensity: intensity))
                intensityTarget = nil
            } onCancel: {
                intensityTarget = nil
            }
            .presentationDetents([.medium])
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

private struct FeelingIntensitySheet: View {
    let type: FeelingType
    var onPick: (FeelingIntensity) -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(FeelingIntensity.allCases) { intensity in
                        Button {
                            onPick(intensity)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(type.intensityTitle(intensity))
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)
                                let subtitle = type.intensitySubtitle(intensity)
                                if !subtitle.isEmpty {
                                    Text(subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text(type.intensityPrompt)
                } footer: {
                    Text(type.rawValue)
                }
            }
            .navigationTitle(type.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }
}
