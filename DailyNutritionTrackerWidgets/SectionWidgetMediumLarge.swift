import SwiftUI
import AppIntents
import WidgetKit

// MARK: - Home Screen Medium

struct SectionMediumView: View {
    let section: WidgetSection
    let snapshot: DaySnapshot

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Label(section.title, systemImage: section.symbolName)
                    .font(.subheadline.weight(.semibold))
                primaryMetrics
                Spacer(minLength: 0)
                secondaryLine
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            actionColumn
                .frame(width: 120)
        }
        .padding(4)
    }

    @ViewBuilder
    private var primaryMetrics: some View {
        switch section {
        case .hydration:
            Text("\(snapshot.waterOz) / \(snapshot.waterTargetOz) oz")
                .font(.title2.bold().monospacedDigit())
            ProgressView(value: snapshot.waterFraction).tint(.cyan)
        case .protein:
            Text("\(snapshot.proteinCalories) / \(snapshot.proteinGoal) kcal")
                .font(.title2.bold().monospacedDigit())
            ProgressView(value: snapshot.proteinFraction).tint(.orange)
        case .smoking:
            Text("\(snapshot.cigarettes)")
                .font(.largeTitle.bold().monospacedDigit())
            if snapshot.cigaretteLimit > 0 {
                Text("of \(snapshot.cigaretteLimit) max")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .drinking:
            Text("\(snapshot.drinks)")
                .font(.largeTitle.bold().monospacedDigit())
            if snapshot.drinkLimit > 0 {
                Text("of \(snapshot.drinkLimit) max")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .bathroom:
            HStack(spacing: 16) {
                labeledValue("Urine", snapshot.urineCount)
                labeledValue("Stool", snapshot.stoolCount)
            }
        case .weight:
            if let w = snapshot.weightLbs {
                Text(String(format: "%.1f lb", w))
                    .font(.title.bold().monospacedDigit())
                HStack(spacing: 8) {
                    if let bmi = snapshot.bmi {
                        Text(String(format: "BMI %.1f", bmi))
                    }
                    if let delta = snapshot.weightDeltaLbs {
                        Text(String(format: "%+.1f lb", delta))
                            .foregroundStyle(delta <= 0 ? .green : .orange)
                    }
                }
                .font(.caption.monospacedDigit())
            } else {
                Text("No weigh-in yet")
                    .font(.title3.weight(.semibold))
            }
        case .workouts:
            Text("\(snapshot.workoutMinutes) min")
                .font(.title.bold().monospacedDigit())
            Text("\(snapshot.workoutCount) sessions")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .feelings:
            Text("\(snapshot.feelingCount)")
                .font(.title.bold().monospacedDigit())
            if let last = snapshot.lastFeelingName {
                Text("Last: \(last)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .checklist:
            Text("\(snapshot.checklistTotal) items")
                .font(.title.bold().monospacedDigit())
            Text("FV \(snapshot.fatsAndVeggiesCount) · Fruit \(snapshot.fruitCount) · Misc \(snapshot.miscCount)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        case .supplements:
            Text("\(snapshot.supplementDosesCompleted) / \(snapshot.supplementDosesTotal)")
                .font(.title.bold().monospacedDigit())
            ProgressView(value: snapshot.supplementFraction).tint(.mint)
        case .dailyStatus:
            statusBadge("On plan", snapshot.followedPlan)
            statusBadge("Ketosis", snapshot.ketosis)
        }
    }

    @ViewBuilder
    private var secondaryLine: some View {
        switch section {
        case .hydration:
            if snapshot.electrolyteCount > 0 {
                Text("\(snapshot.electrolyteCount) electrolyte")
            } else {
                Text("Bottle \(snapshot.bottleLabel) oz")
            }
        case .protein:
            Text("\(snapshot.proteinEntryCount) entries logged")
        case .smoking, .drinking:
            Text(section == .smoking
                  ? (snapshot.smokingEnabled ? "Quick-add on Lock Screen too" : "Enable in Settings")
                  : (snapshot.drinkingEnabled ? "Quick-add on Lock Screen too" : "Enable in Settings"))
        case .bathroom:
            Text("Privacy-friendly counts")
        case .weight:
            if snapshot.goalWeightLbs > 0, let w = snapshot.weightLbs {
                Text(String(format: "%.1f lb to go", w - snapshot.goalWeightLbs))
            } else {
                Text("Tap widget to open Weight")
            }
        case .workouts:
            Text(snapshot.lastWorkoutName.map { "Last: \($0)" } ?? "Tap to add a workout")
        case .feelings:
            Text("Tap to log a feeling")
        case .checklist:
            Text("Tap to add veggies & fats")
        case .supplements:
            Text(snapshot.supplementFraction >= 1 ? "All done" : "Mark next incomplete dose")
        case .dailyStatus:
            Text("Tap badges to toggle")
        }
    }

    @ViewBuilder
    private var actionColumn: some View {
        VStack(spacing: 8) {
            switch section {
            case .hydration:
                Button(intent: AddWaterBottleIntent()) {
                    Label("+\(snapshot.bottleLabel) oz", systemImage: "drop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
            case .protein:
                openHint("Add protein")
            case .smoking:
                if snapshot.smokingEnabled {
                    Button(intent: AddCigaretteIntent()) {
                        Label("Cig", systemImage: "flame.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    Button(intent: AddSmokeUrgeIntent()) {
                        Label("Urge", systemImage: "wind")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else {
                    openHint("Enable smoking")
                }
            case .drinking:
                if snapshot.drinkingEnabled {
                    Button(intent: AddDrinkIntent()) {
                        Label("+1", systemImage: "wineglass.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    Button(intent: AddDrinksIntent(count: 2)) {
                        Text("+2")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else {
                    openHint("Enable drinking")
                }
            case .bathroom:
                Button(intent: AddBathroomIntent(kind: .urine)) {
                    Text("Urine")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button(intent: AddBathroomIntent(kind: .stool)) {
                    Text("Stool")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            case .weight, .workouts, .feelings, .checklist:
                openHint("Open")
            case .supplements:
                Button(intent: MarkNextSupplementIntent()) {
                    Label("Mark next", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.mint)
            case .dailyStatus:
                Button(intent: ToggleFollowedPlanIntent()) {
                    Text("Plan")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                Button(intent: ToggleKetosisIntent()) {
                    Text("Keto")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .font(.caption.weight(.semibold))
    }

    private func labeledValue(_ title: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.title.bold().monospacedDigit())
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func statusBadge(_ title: String, _ on: Bool) -> some View {
        HStack {
            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(on ? .green : .secondary)
            Text(title)
                .font(.subheadline.weight(.semibold))
        }
    }

    private func openHint(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(8)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Home Screen Large / Extra Large

struct SectionLargeView: View {
    let section: WidgetSection
    let snapshot: DaySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(section.title, systemImage: section.symbolName)
                    .font(.headline)
                Spacer()
                Text("Today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            SectionMediumView(section: section, snapshot: snapshot)
                .frame(maxHeight: 140)

            Divider()

            switch section {
            case .hydration:
                detailRow("Electrolytes", "\(snapshot.electrolyteCount)")
                detailRow("Bottle size", "\(snapshot.bottleLabel) oz")
                detailRow("Remaining", "\(max(0, snapshot.waterTargetOz - snapshot.waterOz)) oz")
            case .protein:
                detailRow("Entries", "\(snapshot.proteinEntryCount)")
                detailRow("Remaining", "\(max(0, snapshot.proteinGoal - snapshot.proteinCalories)) kcal")
                Text("Tap widget to open protein logging, meals, or barcode scan.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .smoking:
                detailRow("Cigarettes", "\(snapshot.cigarettes)")
                if snapshot.cigaretteLimit > 0 {
                    detailRow("Daily max", "\(snapshot.cigaretteLimit)")
                }
                detailRow("Mode", snapshot.smokingModeRaw.capitalized)
            case .drinking:
                detailRow("Drinks", "\(snapshot.drinks)")
                if snapshot.drinkLimit > 0 {
                    detailRow("Daily max", "\(snapshot.drinkLimit)")
                }
                HStack(spacing: 8) {
                    Button(intent: AddDrinksIntent(count: 1)) { Text("+1") }
                    Button(intent: AddDrinksIntent(count: 2)) { Text("+2") }
                    Button(intent: AddDrinksIntent(count: 3)) { Text("+3") }
                    Button(intent: AddDrinkUrgeIntent()) { Text("Urge") }
                }
                .buttonStyle(.bordered)
                .font(.caption.weight(.semibold))
            case .bathroom:
                detailRow("Urination", "\(snapshot.urineCount)")
                detailRow("Bowel", "\(snapshot.stoolCount)")
                Text("Adds a timestamped event — edit notes in the app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .weight:
                if let w = snapshot.weightLbs {
                    detailRow("Weight", String(format: "%.1f lb", w))
                }
                if let bmi = snapshot.bmi {
                    detailRow("BMI", String(format: "%.1f", bmi))
                }
                if snapshot.goalWeightLbs > 0 {
                    detailRow("Goal", String(format: "%.1f lb", snapshot.goalWeightLbs))
                }
                Text("Tap to open Weight & BMI.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .workouts:
                detailRow("Sessions", "\(snapshot.workoutCount)")
                detailRow("Minutes", "\(snapshot.workoutMinutes)")
                if let name = snapshot.lastWorkoutName {
                    detailRow("Last", name)
                }
            case .feelings:
                detailRow("Logged", "\(snapshot.feelingCount)")
                if let last = snapshot.lastFeelingName {
                    detailRow("Latest", last)
                }
            case .checklist:
                detailRow("Fats & veggies", "\(snapshot.fatsAndVeggiesCount)")
                detailRow("Fruit", "\(snapshot.fruitCount)")
                detailRow("Misc", "\(snapshot.miscCount)/\(AppLimits.miscDailyLimit)")
            case .supplements:
                ForEach(snapshot.supplements.prefix(6)) { item in
                    HStack {
                        Text(item.name)
                        Spacer()
                        Text("\(item.completed)/\(item.dosesPerDay)")
                            .monospacedDigit()
                            .foregroundStyle(item.isComplete ? .green : .primary)
                    }
                    .font(.caption)
                }
                if snapshot.supplements.count > 6 {
                    Text("+\(snapshot.supplements.count - 6) more in app")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            case .dailyStatus:
                detailRow("Protein", "\(snapshot.proteinCalories)/\(snapshot.proteinGoal)")
                detailRow("Water", "\(snapshot.waterOz)/\(snapshot.waterTargetOz) oz")
                HStack(spacing: 8) {
                    Button(intent: ToggleFollowedPlanIntent()) {
                        Label(snapshot.followedPlan ? "On plan" : "Off plan", systemImage: "checkmark.seal")
                    }
                    Button(intent: ToggleKetosisIntent()) {
                        Label(snapshot.ketosis ? "In ketosis" : "Not keto", systemImage: "flame")
                    }
                }
                .buttonStyle(.bordered)
                .font(.caption.weight(.semibold))
            }

            Spacer(minLength: 0)
        }
        .padding(6)
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
    }
}
