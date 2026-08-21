import SwiftUI
import SwiftData

/// Adding a fat, veg, fruit or misc item, brought up to the protein log's standard: type
/// anything, scan a barcode, or search Open Food Facts — the built-in catalogue is a
/// suggestion, not the only way in.
///
/// Replaces `FoodChecklistPicker`, which could only pick from a fixed catalogue and had
/// no free-text or scan path.
struct ChecklistAddSheet: View {
    let category: FoodCategory
    let phase: ProgramPhase
    var excludedNames: [String] = []
    /// name + amount, already resolved — the caller just stores it.
    let onAdd: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var search = ""
    @State private var amount = ""
    @State private var recent: [SuggestionItem] = []
    @State private var showScanner = false
    @State private var remoteResults: [RemoteFoodCandidate] = []
    @State private var isSearchingRemote = false
    @State private var lookupError: String?

    private var trimmedSearch: String {
        search.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var catalogMatches: [CatalogFood] {
        let excluded = Set(excludedNames.map { $0.lowercased() })
        return FoodCatalog.foods(category: category, phase: phase, search: trimmedSearch)
            .filter { !excluded.contains($0.name.lowercased()) }
    }

    /// Only offer "add what I typed" when it isn't already an exact catalogue hit.
    private var showsFreeTextRow: Bool {
        guard !trimmedSearch.isEmpty else { return false }
        return !catalogMatches.contains { $0.name.caseInsensitiveCompare(trimmedSearch) == .orderedSame }
    }

    var body: some View {
        NavigationStack {
            List {
                if showsFreeTextRow {
                    Section {
                        Button {
                            add(name: trimmedSearch, amount: resolvedAmount(for: trimmedSearch))
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Add “\(trimmedSearch)”")
                                        .foregroundStyle(.primary)
                                    Text("Not in the list — log it anyway")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "plus.circle.fill")
                            }
                        }
                    }
                }

                Section {
                    TextField(amountPlaceholder, text: $amount)
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Amount")
                } footer: {
                    Text("Optional. Left blank, a sensible default for the item is used.")
                }

                if !recent.isEmpty && trimmedSearch.isEmpty {
                    Section("Recent") {
                        ForEach(recent) { item in
                            Button {
                                add(name: item.name, amount: item.amount ?? resolvedAmount(for: item.name))
                            } label: {
                                row(title: item.name, subtitle: item.subtitle ?? item.amount)
                            }
                        }
                    }
                }

                if !catalogMatches.isEmpty {
                    Section(trimmedSearch.isEmpty ? "Common \(category.title.lowercased())" : "Matches") {
                        ForEach(catalogMatches) { food in
                            Button {
                                add(name: food.name, amount: amountOverride ?? food.servingLabel)
                            } label: {
                                row(title: food.name, subtitle: food.servingLabel)
                            }
                        }
                    }
                }

                if !remoteResults.isEmpty {
                    Section("Open Food Facts") {
                        ForEach(remoteResults) { candidate in
                            Button {
                                add(name: candidate.name, amount: amountOverride ?? candidate.servingLabel)
                            } label: {
                                row(title: candidate.name, subtitle: candidate.subtitle)
                            }
                        }
                    }
                }

                if !trimmedSearch.isEmpty {
                    Section {
                        Button {
                            Task { await searchRemote() }
                        } label: {
                            if isSearchingRemote {
                                HStack(spacing: Spacing.s) {
                                    ProgressView()
                                    Text("Searching…")
                                }
                            } else {
                                Label("Search Open Food Facts", systemImage: "magnifyingglass")
                            }
                        }
                        .disabled(isSearchingRemote)
                    } footer: {
                        if let lookupError {
                            Text(lookupError)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "Search or type anything")
            .navigationTitle("Add \(category.title.lowercased())")
            .onPlanInlineNav()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showScanner = true
                    } label: {
                        Image(systemName: "barcode.viewfinder")
                    }
                    .accessibilityLabel("Scan barcode")
                }
            }
            .sheet(isPresented: $showScanner) {
                BarcodeScannerSheet { code in
                    Task { await lookUp(barcode: code) }
                }
            }
            .task {
                recent = UsageSuggestions.checklistChips(category: category, phase: phase, in: modelContext)
            }
        }
    }

    private var amountPlaceholder: String {
        ChecklistStorage.defaultAmount(for: "", category: category).isEmpty
            ? "e.g. 1 cup"
            : "e.g. \(ChecklistStorage.defaultAmount(for: "", category: category))"
    }

    private var amountOverride: String? {
        let trimmed = amount.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func resolvedAmount(for name: String) -> String {
        amountOverride ?? ChecklistStorage.defaultAmount(for: name, category: category)
    }

    private func row(title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .foregroundStyle(.primary)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func add(name: String, amount: String) {
        onAdd(name, amount)
        dismiss()
    }

    private func searchRemote() async {
        isSearchingRemote = true
        lookupError = nil
        defer { isSearchingRemote = false }
        do {
            remoteResults = try await OpenFoodFactsClient.search(query: trimmedSearch)
            if remoteResults.isEmpty {
                lookupError = "Nothing found for “\(trimmedSearch)”. You can still add it by name."
            }
        } catch {
            lookupError = "Couldn't reach Open Food Facts. You can still add it by name."
        }
    }

    private func lookUp(barcode: String) async {
        lookupError = nil
        do {
            let candidate = try await OpenFoodFactsClient.product(barcode: barcode)
            add(name: candidate.name, amount: amountOverride ?? candidate.servingLabel)
        } catch {
            lookupError = "That barcode wasn't found. Try typing the name instead."
            search = ""
        }
    }
}
