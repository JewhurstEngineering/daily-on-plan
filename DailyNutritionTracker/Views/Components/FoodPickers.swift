import SwiftUI

struct MultiplierPicker: View {
    @Binding var multiplier: Double
    var options: [Double] = [1, 2, 3, 4, 5, 6]
    var onSelect: ((Double) -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { value in
                let selected = abs(multiplier - value) < 0.01
                Button {
                    multiplier = value
                    onSelect?(value)
                } label: {
                    Text("\(Int(value))×")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selected ? Color.accentColor : Color.onPlanTertiaryFill)
                        .foregroundStyle(selected ? Color.white : Color.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct FoodChecklistPicker: View {
    let category: FoodCategory
    let phase: ProgramPhase
    var excludedNames: [String] = []
    let onPick: (CatalogFood) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var foods: [CatalogFood] {
        let excluded = Set(excludedNames.map { $0.lowercased() })
        return FoodCatalog.foods(category: category, phase: phase, search: search)
            .filter { !excluded.contains($0.name.lowercased()) }
    }

    var body: some View {
        NavigationStack {
            List(foods) { food in
                Button {
                    onPick(food)
                    dismiss()
                } label: {
                    VStack(alignment: .leading) {
                        Text(food.name)
                        Text(food.servingLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .searchable(text: $search)
            .navigationTitle(category.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
