import SwiftUI
import SwiftData
import OnPlanCore

/// Fills in macros for food logged before the app tracked them.
///
/// Works food-by-food rather than entry-by-entry: "chicken breast" logged eighteen times is one
/// decision, not eighteen. Saving writes per-serving macros onto every matching entry, scaled by
/// what each one actually logged, and remembers them on the preset so the food never has to be
/// answered again.
struct MacroBackfillView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomFoodPreset.name) private var presets: [CustomFoodPreset]

    @State private var groups: [BackfillGroup] = []
    @State private var editing: BackfillGroup?
    @State private var justSaved: String?

    var body: some View {
        List {
            if groups.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Nothing to fill in",
                        systemImage: "checkmark.circle",
                        description: Text(
                            "Every food you've logged already carries macros. New ones fill "
                            + "themselves in when you scan or type them once."
                        )
                    )
                }
            } else {
                Section {
                    ForEach(groups) { group in
                        Button {
                            editing = group
                        } label: {
                            row(group)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("\(groups.count) foods without macros")
                } footer: {
                    Text("Filling one in updates every day you logged it, and remembers it for "
                         + "next time. Nothing is changed until you save.")
                }
            }
        }
        .navigationTitle("Fill in macros")
        .onPlanInlineNav()
        .sheet(item: $editing) { group in
            MacroBackfillEditor(group: group) { perServing in
                apply(perServing, to: group)
                editing = nil
                reload()
            } onCancel: {
                editing = nil
            }
        }
        .onAppear(perform: reload)
    }

    private func row(_ group: BackfillGroup) -> some View {
        HStack(spacing: Spacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.body)
                Text(group.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: Spacing.s)
            if justSaved == group.name {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    // MARK: - Data

    private func reload() {
        let logs = (try? modelContext.fetch(FetchDescriptor<DailyLog>())) ?? []
        let entries = logs.flatMap(\.proteins).filter { $0.macros == nil }

        var byName: [String: [ProteinEntry]] = [:]
        for entry in entries {
            byName[entry.name.trimmingCharacters(in: .whitespaces), default: []].append(entry)
        }

        groups = byName
            .filter { !$0.key.isEmpty }
            .map { name, entries in
                BackfillGroup(name: name, entries: entries.sorted { $0.time > $1.time })
            }
            // Most recently eaten first: the foods still in rotation are worth answering.
            .sorted { ($0.lastLogged ?? .distantPast) > ($1.lastLogged ?? .distantPast) }
    }

    /// Writes per-serving macros onto every entry in the group, scaled to what each one logged.
    private func apply(_ perServing: Macros, to group: BackfillGroup) {
        for entry in group.entries {
            entry.macros = perServing.scaled(by: max(entry.servings, 0.01))
        }
        rememberOnPreset(perServing, group: group)
        try? modelContext.save()
        justSaved = group.name
        WidgetReloader.reloadAll()
    }

    private func rememberOnPreset(_ macros: Macros, group: BackfillGroup) {
        let key = group.name.lowercased()
        if let existing = presets.first(where: { $0.name.lowercased() == key }) {
            existing.macros = macros
            return
        }
        guard let sample = group.entries.first else { return }
        let unitCalories = sample.servings > 0
            ? max(1, Int((Double(sample.calories) / sample.servings).rounded()))
            : max(sample.calories, 1)
        let preset = CustomFoodPreset(
            name: group.name,
            servingLabel: sample.servingSize.isEmpty ? "1 serving" : sample.servingSize,
            calories: unitCalories,
            category: FoodCategory.protein.rawValue,
            proteinCategory: sample.proteinCategory,
            servingsPerUnit: 1,
            macros: macros
        )
        modelContext.insert(preset)
    }
}

/// One food name and every entry of it still missing macros.
struct BackfillGroup: Identifiable {
    let name: String
    let entries: [ProteinEntry]

    var id: String { name }

    var lastLogged: Date? { entries.first?.time }

    /// Calories for a single serving, averaged over how it has actually been logged.
    var unitCalories: Int {
        let units = entries.map { entry -> Double in
            entry.servings > 0 ? Double(entry.calories) / entry.servings : Double(entry.calories)
        }
        guard !units.isEmpty else { return 0 }
        return max(1, Int((units.reduce(0, +) / Double(units.count)).rounded()))
    }

    var proteinCategory: String { entries.first?.proteinCategory ?? "other" }

    var detail: String {
        var parts = ["\(entries.count) × logged", "\(unitCalories) kcal per serving"]
        if let last = lastLogged {
            parts.append("last \(last.formatted(.dateTime.month(.abbreviated).day()))")
        }
        return parts.joined(separator: " · ")
    }
}

/// The per-food form, prefilled from the exchange chart where the chart applies.
private struct MacroBackfillEditor: View {
    let group: BackfillGroup
    var onSave: (Macros) -> Void
    var onCancel: () -> Void

    @State private var draft = MacroDraft()
    @State private var didPrefill = false

    private var estimate: Macros? {
        guard let category = ExchangeEstimate.category(forRawValue: group.proteinCategory) else {
            return nil
        }
        return ExchangeEstimate.macros(calories: group.unitCalories, category: category)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Logged", value: "\(group.entries.count) times")
                    LabeledContent("Per serving", value: "\(group.unitCalories) kcal")
                } header: {
                    Text(group.name)
                } footer: {
                    Text("These numbers are for **one serving**. Every day you logged this food "
                         + "gets them scaled to the amount you had.")
                }

                if let estimate, !didPrefill {
                    Section {
                        Button {
                            draft = MacroDraft(estimate)
                            draft.source = .estimated
                            didPrefill = true
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Label("Use the exchange-chart estimate", systemImage: "wand.and.stars")
                                Text(estimate.compactSummary)
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } footer: {
                        Text("Every meat exchange on the chart is 7 g of protein — the categories "
                             + "differ only in fat. It's a starting point, not a measurement.")
                    }
                }

                MacroFieldsSection(
                    draft: $draft,
                    derivedKcal: draft.macros?.resolvedKcal,
                    showsMoreByDefault: false
                )
            }
            .navigationTitle("Fill in macros")
            .onPlanInlineNav()
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { Keyboard.dismiss() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard var macros = draft.macros else { return }
                        // Anything the user touched is theirs, not an estimate.
                        if draft.source != .estimated || macros != estimate {
                            macros.source = .manual
                        }
                        onSave(macros)
                    }
                    .disabled(draft.isEmpty)
                }
            }
        }
    }
}
