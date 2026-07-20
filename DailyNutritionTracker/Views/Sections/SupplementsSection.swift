import SwiftUI
import SwiftData

struct SupplementsSection: View {
    @Bindable var log: DailyLog
    @Bindable var settings: AppSettings
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        SectionCard(title: "Supplements", systemImage: "pills") {
            ForEach(settings.supplements) { supplement in
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
            Text("Consult your healthcare provider for individualized supplement schedules.")
                .font(.caption2)
                .foregroundStyle(.secondary)
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
