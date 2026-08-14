import SwiftUI
import SwiftData

struct MotivationQuotesSettingsView: View {
    @Bindable var settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @State private var draft = ""
    @State private var showBuiltIns = false

    var body: some View {
        Form {
            Section {
                TextField("Add your own quote", text: $draft, axis: .vertical)
                    .lineLimit(2...4)
                Button("Add quote") {
                    let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    var list = settings.customMotivationQuotes
                    list.append(trimmed)
                    settings.customMotivationQuotes = list
                    draft = ""
                    save()
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } footer: {
                Text("Custom quotes are mixed into the daily motivation notification when it’s enabled.")
            }

            Section("Your quotes") {
                if settings.customMotivationQuotes.isEmpty {
                    Text("None yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(settings.customMotivationQuotes.enumerated()), id: \.offset) { index, quote in
                        Text(quote)
                            .font(.body)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                var list = settings.customMotivationQuotes
                                list.remove(at: index)
                                settings.customMotivationQuotes = list
                                save()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete { offsets in
                        var list = settings.customMotivationQuotes
                        list.remove(atOffsets: offsets)
                        settings.customMotivationQuotes = list
                        save()
                    }
                }
            }

            Section {
                Toggle("Show built-in library (\(MotivationQuoteStore.builtIn.count))", isOn: $showBuiltIns)
                if showBuiltIns {
                    ForEach(MotivationQuoteStore.builtIn, id: \.self) { quote in
                        Text(quote)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("Built-ins can’t be edited. Add your own above if you want personal lines.")
            }
        }
        .navigationTitle("Motivational quotes")
        .onPlanInlineNav()
    }

    private func save() {
        modelContext.saveAndNotifyJournal()
        Task { await NotificationService.shared.reschedule(using: settings) }
    }
}
