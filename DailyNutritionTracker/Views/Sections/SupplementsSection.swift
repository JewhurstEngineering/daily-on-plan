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
                Text("No supplements visible. Tap the gear to enable some.")
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
                    Text("Show or hide supplements without deleting them. Adjust doses per day as needed.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(settings.supplements.enumerated()), id: \.element.id) { index, supplement in
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(supplement.name, isOn: Binding(
                            get: { settings.supplements[index].isEnabled },
                            set: { newValue in
                                var list = settings.supplements
                                list[index].isEnabled = newValue
                                settings.supplements = list
                                try? modelContext.save()
                            }
                        ))
                        if settings.supplements[index].isEnabled {
                            Stepper(
                                "\(settings.supplements[index].dosesPerDay) doses/day",
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
                            .font(.caption)
                        }
                    }
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
