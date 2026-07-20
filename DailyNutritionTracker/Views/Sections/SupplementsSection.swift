import SwiftUI
import SwiftData

struct SupplementsSection: View {
    @Bindable var log: DailyLog
    @Bindable var settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @State private var showConfig = false

    var body: some View {
        SectionCard(
            title: "Supplements",
            systemImage: "pills",
            trailing: {
                Button {
                    showConfig = true
                } label: {
                    Image(systemName: "gearshape.fill")
                }
                .accessibilityLabel("Configure supplements")
            }
        ) {
            let visible = settings.visibleSupplements
            if visible.isEmpty {
                Text("No supplements visible. Tap the gear to enable some, or turn the section off in Settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(visible) { supplement in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(supplement.name)
                            .font(.subheadline.weight(.semibold))
                        HStack(spacing: 8) {
                            ForEach(0..<supplement.dosesPerDay, id: \.self) { index in
                                let key = supplement.doseKey(index)
                                Button {
                                    toggle(key)
                                } label: {
                                    Image(systemName: log.completedSupplements.contains(key) ? "checkmark.square.fill" : "square")
                                        .font(.title3)
                                        .foregroundStyle(Color.accentColor)
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer()
                            Text("\(completedCount(supplement))/\(supplement.dosesPerDay)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    Divider()
                }
            }
            Text("Consult your healthcare provider for individualized supplement schedules.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .sheet(isPresented: $showConfig) {
            SupplementConfigSheet(settings: settings)
        }
    }

    private func completedCount(_ supplement: SupplementDefinition) -> Int {
        (0..<supplement.dosesPerDay).filter { log.completedSupplements.contains(supplement.doseKey($0)) }.count
    }

    private func toggle(_ key: String) {
        if log.completedSupplements.contains(key) {
            log.completedSupplements.removeAll { $0 == key }
        } else {
            log.completedSupplements.append(key)
        }
        try? modelContext.save()
    }
}

struct SupplementConfigSheet: View {
    @Bindable var settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Show or hide items without deleting them. Use Disable all to clear the daily checklist.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Disable all") {
                        var list = settings.supplements
                        for i in list.indices { list[i].isEnabled = false }
                        settings.supplements = list
                        try? modelContext.save()
                    }
                    Button("Enable all") {
                        var list = settings.supplements
                        for i in list.indices { list[i].isEnabled = true }
                        settings.supplements = list
                        try? modelContext.save()
                    }
                }

                ForEach(Array(settings.supplements.enumerated()), id: \.element.id) { index, supplement in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(supplement.name)
                                .font(.body)
                            if settings.supplements[index].isEnabled {
                                Text("\(settings.supplements[index].dosesPerDay) doses/day")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Hidden")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 8)
                        if settings.supplements[index].isEnabled {
                            Stepper(
                                "",
                                value: Binding(
                                    get: { settings.supplements[index].dosesPerDay },
                                    set: { newValue in
                                        var list = settings.supplements
                                        list[index].dosesPerDay = newValue
                                        settings.supplements = list
                                        try? modelContext.save()
                                    }
                                ),
                                in: 1...6
                            )
                            .labelsHidden()
                            .fixedSize()
                        }
                        Toggle(
                            "",
                            isOn: Binding(
                                get: { settings.supplements[index].isEnabled },
                                set: { newValue in
                                    var list = settings.supplements
                                    list[index].isEnabled = newValue
                                    settings.supplements = list
                                    try? modelContext.save()
                                }
                            )
                        )
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .scaleEffect(0.85)
                        .fixedSize()
                    }
                    .padding(.vertical, 2)
                }
            }
            .navigationTitle("Configure Supplements")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
