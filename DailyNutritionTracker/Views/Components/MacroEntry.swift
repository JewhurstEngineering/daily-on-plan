import SwiftUI
import OnPlanCore

/// Text-backed mirror of `Macros` for entry forms.
///
/// Fields are strings because a nutrition field has three states — empty (never recorded),
/// "0", and a number — and a `Double?` bound to a TextField cannot express the first while the
/// user is mid-edit.
struct MacroDraft: Equatable {
    var protein = ""
    var totalCarb = ""
    var fiber = ""
    var sugars = ""
    var addedSugars = ""
    var sugarAlcohols = ""
    var fat = ""
    var saturatedFat = ""
    var transFat = ""
    var cholesterolMg = ""
    var sodiumMg = ""
    var alcohol = ""

    /// Whether the carb figure already excludes fibre (an EU-style label).
    var carbsExcludeFiber = false
    /// kcal printed on the package, when the user chooses to override the computed figure.
    var labelKcal = ""
    /// Set when a lookup guessed the carb convention rather than reading it — surfaces the toggle.
    var carbBasisWasGuessed = false

    var source: Macros.Source = .manual

    init() {}

    init(_ macros: Macros?) {
        guard let macros else { return }
        protein = MacroDraft.text(macros.protein)
        totalCarb = MacroDraft.text(macros.totalCarb)
        fiber = MacroDraft.text(macros.fiber)
        sugars = MacroDraft.text(macros.sugars)
        addedSugars = MacroDraft.text(macros.addedSugars)
        sugarAlcohols = MacroDraft.text(macros.sugarAlcohols)
        fat = MacroDraft.text(macros.fat)
        saturatedFat = MacroDraft.text(macros.saturatedFat)
        transFat = MacroDraft.text(macros.transFat)
        cholesterolMg = MacroDraft.text(macros.cholesterolMg)
        sodiumMg = MacroDraft.text(macros.sodiumMg)
        alcohol = MacroDraft.text(macros.alcohol)
        carbsExcludeFiber = macros.carbBasis == .available
        labelKcal = macros.labelKcal.map(String.init) ?? ""
        source = macros.source
    }

    private static func text(_ value: Double?) -> String {
        Macros.gramsText(value) ?? ""
    }

    private static func number(_ text: String) -> Double? {
        let cleaned = text.replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty, let value = Double(cleaned) else { return nil }
        return max(0, value)
    }

    /// The macro set as typed. Nil when nothing has been entered.
    var macros: Macros? {
        let result = Macros(
            protein: MacroDraft.number(protein),
            totalCarb: MacroDraft.number(totalCarb),
            fiber: MacroDraft.number(fiber),
            sugars: MacroDraft.number(sugars),
            addedSugars: MacroDraft.number(addedSugars),
            sugarAlcohols: MacroDraft.number(sugarAlcohols),
            fat: MacroDraft.number(fat),
            saturatedFat: MacroDraft.number(saturatedFat),
            transFat: MacroDraft.number(transFat),
            cholesterolMg: MacroDraft.number(cholesterolMg),
            sodiumMg: MacroDraft.number(sodiumMg),
            alcohol: MacroDraft.number(alcohol),
            carbBasis: carbsExcludeFiber ? .available : .total,
            source: source,
            labelKcal: MacroDraft.number(labelKcal).map { Int($0) }
        )
        return result.isEmpty ? nil : result
    }

    var isEmpty: Bool { macros == nil }

    /// True once enough is filled in to derive a calorie figure.
    var canDeriveCalories: Bool { macros?.computedKcal != nil }
}

// MARK: - Fields

/// The macro block: the five that matter, then everything else behind a disclosure.
struct MacroFieldsSection: View {
    @Binding var draft: MacroDraft
    /// Shown under the fields; the calorie figure these macros produce. Per serving, like the
    /// fields above it — the scaled total belongs in the Amount section.
    var derivedKcal: Int?
    var showsMoreByDefault = false

    @State private var showsMore = false
    @FocusState private var focused: Field?

    fileprivate enum Field: Hashable {
        case protein, carb, fiber, sugars, fat
        case addedSugars, sugarAlcohols, satFat, transFat, cholesterol, sodium, alcohol, labelKcal
    }

    var body: some View {
        Section {
            field("Protein", text: $draft.protein, unit: "g", focus: .protein)
            field("Carbs", text: $draft.totalCarb, unit: "g", focus: .carb)
            field("Fiber", text: $draft.fiber, unit: "g", focus: .fiber)
            field("Sugars", text: $draft.sugars, unit: "g", focus: .sugars)
            field("Fat", text: $draft.fat, unit: "g", focus: .fat)

            if draft.carbBasisWasGuessed || draft.carbsExcludeFiber {
                Toggle("Carbs already exclude fiber", isOn: $draft.carbsExcludeFiber)
                    .font(.subheadline)
            }

            DisclosureGroup("More nutrients", isExpanded: $showsMore) {
                field("Added sugars", text: $draft.addedSugars, unit: "g", focus: .addedSugars)
                field("Sugar alcohols", text: $draft.sugarAlcohols, unit: "g", focus: .sugarAlcohols)
                field("Saturated fat", text: $draft.saturatedFat, unit: "g", focus: .satFat)
                field("Trans fat", text: $draft.transFat, unit: "g", focus: .transFat)
                field("Cholesterol", text: $draft.cholesterolMg, unit: "mg", focus: .cholesterol)
                field("Sodium", text: $draft.sodiumMg, unit: "mg", focus: .sodium)
                field("Alcohol", text: $draft.alcohol, unit: "g", focus: .alcohol)
            }

            MacroCalorieSummary(draft: $draft, derivedKcal: derivedKcal, focus: $focused)
        } header: {
            Text("Nutrition")
        } footer: {
            Text(footerText)
        }
        .onAppear { showsMore = showsMoreByDefault }
    }

    private var footerText: String {
        if draft.carbsExcludeFiber {
            return "Carbs are treated as already excluding fiber, the way EU labels print them. "
                + "Net carbs won't subtract it a second time."
        }
        return "Type what's on the label — calories are worked out for you. "
            + "Net carbs subtract fiber and sugar alcohols."
    }

    private func field(
        _ label: String,
        text: Binding<String>,
        unit: String,
        focus: Field
    ) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("—", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 70)
                .focused($focused, equals: focus)
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .leading)
        }
    }
}

/// The calorie readout: a result of the macros, not a field to fill — with an override for the
/// figure printed on the package, which is authoritative when the two disagree.
private struct MacroCalorieSummary: View {
    @Binding var draft: MacroDraft
    var derivedKcal: Int?
    @FocusState.Binding var focus: MacroFieldsSection.Field?

    @State private var isOverriding = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Calories per serving")
                Spacer()
                if isOverriding || !draft.labelKcal.isEmpty {
                    TextField("kcal", text: $draft.labelKcal)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 70)
                        .focused($focus, equals: .labelKcal)
                    Text("kcal")
                        .foregroundStyle(.secondary)
                        .frame(width: 34, alignment: .leading)
                } else {
                    Button {
                        isOverriding = true
                        focus = .labelKcal
                    } label: {
                        HStack(spacing: 4) {
                            Text(derivedKcal.map { "\($0)" } ?? "—")
                                .monospacedDigit()
                                .fontWeight(.semibold)
                            Text("kcal")
                                .foregroundStyle(.secondary)
                            Image(systemName: "pencil")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            if let macros = draft.macros {
                if NutritionMath.kcalLooksInconsistent(macros), let computed = macros.computedKcal {
                    Label(
                        "The macros work out to \(computed) kcal — check the numbers.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                } else if let net = Macros.gramsText(macros.netCarb) {
                    Text("Net carbs \(net) g")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
