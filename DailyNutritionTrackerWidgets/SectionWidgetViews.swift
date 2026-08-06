import SwiftUI
import AppIntents
import WidgetKit

// MARK: - Circular (Lock Screen)

struct SectionCircularView: View {
    let section: WidgetSection
    let snapshot: DaySnapshot

    var body: some View {
        switch section {
        case .hydration:
            Gauge(value: snapshot.waterFraction) {
                Text("Water")
            } currentValueLabel: {
                Text("\(snapshot.waterOz)")
            }
            .gaugeStyle(.accessoryCircularCapacity)
        case .protein:
            Gauge(value: snapshot.proteinFraction) {
                Text("Protein")
            } currentValueLabel: {
                Text("\(snapshot.proteinCalories)")
            }
            .gaugeStyle(.accessoryCircularCapacity)
        case .smoking:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                    Text("\(snapshot.cigarettes)")
                        .font(.headline.bold().monospacedDigit())
                }
            }
        case .drinking:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "wineglass.fill")
                        .font(.caption2)
                    Text("\(snapshot.drinks)")
                        .font(.headline.bold().monospacedDigit())
                }
            }
        case .bathroom:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text("\(snapshot.bathroomTotal)")
                        .font(.headline.bold().monospacedDigit())
                    Text("today")
                        .font(.system(size: 8))
                }
            }
        case .weight:
            ZStack {
                AccessoryWidgetBackground()
                if let w = snapshot.weightLbs {
                    Text(String(format: "%.0f", w))
                        .font(.headline.bold().monospacedDigit())
                } else {
                    Image(systemName: "scalemass.fill")
                }
            }
        case .workouts:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text("\(snapshot.workoutMinutes)")
                        .font(.headline.bold().monospacedDigit())
                    Text("min")
                        .font(.system(size: 8))
                }
            }
        case .feelings:
            ZStack {
                AccessoryWidgetBackground()
                Text("\(snapshot.feelingCount)")
                    .font(.title2.bold().monospacedDigit())
            }
        case .checklist:
            ZStack {
                AccessoryWidgetBackground()
                Text("\(snapshot.checklistTotal)")
                    .font(.title2.bold().monospacedDigit())
            }
        case .supplements:
            Gauge(value: snapshot.supplementFraction) {
                Text("Supp")
            } currentValueLabel: {
                Text("\(snapshot.supplementDosesCompleted)")
            }
            .gaugeStyle(.accessoryCircularCapacity)
        case .dailyStatus:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: snapshot.followedPlan ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .font(.title2)
            }
        }
    }
}

// MARK: - Rectangular (Lock Screen)

struct SectionRectangularView: View {
    let section: WidgetSection
    let snapshot: DaySnapshot

    var body: some View {
        switch section {
        case .hydration:
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Water", systemImage: "drop.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(snapshot.waterOz)/\(snapshot.waterTargetOz) oz")
                        .font(.caption.weight(.semibold).monospacedDigit())
                }
                Spacer(minLength: 0)
                Button(intent: AddWaterBottleIntent()) {
                    Text("+\(snapshot.bottleLabel)")
                        .font(.caption2.weight(.bold))
                }
                .buttonStyle(.plain)
            }
        case .protein:
            VStack(alignment: .leading, spacing: 2) {
                Label("Protein", systemImage: "fork.knife")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(snapshot.proteinCalories)/\(snapshot.proteinGoal) kcal")
                    .font(.caption.weight(.semibold).monospacedDigit())
                ProgressView(value: snapshot.proteinFraction)
            }
        case .smoking:
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cigs today")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(snapshot.cigarettes)")
                        .font(.caption.weight(.semibold).monospacedDigit())
                }
                Spacer()
                if snapshot.smokingEnabled {
                    Button(intent: AddCigaretteIntent()) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(.plain)
                }
            }
        case .drinking:
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Drinks today")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(snapshot.drinks)")
                        .font(.caption.weight(.semibold).monospacedDigit())
                }
                Spacer()
                if snapshot.drinkingEnabled {
                    Button(intent: AddDrinkIntent()) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(.plain)
                }
            }
        case .bathroom:
            HStack(spacing: 10) {
                Text("U \(snapshot.urineCount)")
                    .font(.caption.weight(.semibold).monospacedDigit())
                Text("S \(snapshot.stoolCount)")
                    .font(.caption.weight(.semibold).monospacedDigit())
                Spacer(minLength: 0)
                Button(intent: AddBathroomIntent(kind: .urine)) {
                    Image(systemName: "drop")
                }
                .buttonStyle(.plain)
                Button(intent: AddBathroomIntent(kind: .stool)) {
                    Image(systemName: "leaf")
                }
                .buttonStyle(.plain)
            }
        case .weight:
            weightGlance(compact: true)
        case .workouts:
            VStack(alignment: .leading, spacing: 2) {
                Text("\(snapshot.workoutMinutes) min · \(snapshot.workoutCount) sessions")
                    .font(.caption.weight(.semibold).monospacedDigit())
                if let name = snapshot.lastWorkoutName {
                    Text(name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        case .feelings:
            VStack(alignment: .leading, spacing: 2) {
                Text("\(snapshot.feelingCount) feelings")
                    .font(.caption.weight(.semibold))
                if let last = snapshot.lastFeelingName {
                    Text(last)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        case .checklist:
            Text("FV \(snapshot.fatsAndVeggiesCount) · Fruit \(snapshot.fruitCount) · Misc \(snapshot.miscCount)")
                .font(.caption2.weight(.semibold).monospacedDigit())
                .frame(maxWidth: .infinity, alignment: .leading)
        case .supplements:
            HStack {
                Text("\(snapshot.supplementDosesCompleted)/\(snapshot.supplementDosesTotal) doses")
                    .font(.caption.weight(.semibold).monospacedDigit())
                Spacer()
                Button(intent: MarkNextSupplementIntent()) {
                    Image(systemName: "checkmark.circle.fill")
                }
                .buttonStyle(.plain)
            }
        case .dailyStatus:
            HStack(spacing: 8) {
                Button(intent: ToggleFollowedPlanIntent()) {
                    Label(snapshot.followedPlan ? "Plan" : "Off", systemImage: snapshot.followedPlan ? "checkmark.seal.fill" : "xmark.seal")
                        .font(.caption2.weight(.semibold))
                }
                .buttonStyle(.plain)
                Button(intent: ToggleKetosisIntent()) {
                    Label(snapshot.ketosis ? "Keto" : "No keto", systemImage: "flame")
                        .font(.caption2.weight(.semibold))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func weightGlance(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let w = snapshot.weightLbs {
                Text(String(format: "%.1f lb", w))
                    .font((compact ? Font.caption : Font.title3).weight(.semibold).monospacedDigit())
                HStack(spacing: 6) {
                    if let bmi = snapshot.bmi {
                        Text(String(format: "BMI %.1f", bmi))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let delta = snapshot.weightDeltaLbs {
                        Text(String(format: "%+.1f", delta))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(delta <= 0 ? .green : .orange)
                    }
                }
            } else {
                Text("No weigh-in")
                    .font(.caption.weight(.semibold))
                Text("Tap to log")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Home Screen Small

struct SectionSmallView: View {
    let section: WidgetSection
    let snapshot: DaySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(section.title, systemImage: section.symbolName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            switch section {
            case .hydration:
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(snapshot.waterOz)")
                        .font(.largeTitle.bold().monospacedDigit())
                    Text("/ \(snapshot.waterTargetOz) oz")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: snapshot.waterFraction).tint(.cyan)
                Spacer(minLength: 0)
                Button(intent: AddWaterBottleIntent()) {
                    Label("+\(snapshot.bottleLabel) oz", systemImage: "drop.fill")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)

            case .protein:
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(snapshot.proteinCalories)")
                        .font(.largeTitle.bold().monospacedDigit())
                    Text("/ \(snapshot.proteinGoal) kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: snapshot.proteinFraction).tint(.orange)
                Spacer(minLength: 0)
                Text("\(snapshot.proteinEntryCount) entries · tap to add")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

            case .smoking:
                Text("\(snapshot.cigarettes)")
                    .font(.largeTitle.bold().monospacedDigit())
                Text(limitLine(current: snapshot.cigarettes, limit: snapshot.cigaretteLimit, enabled: snapshot.smokingEnabled))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if snapshot.smokingEnabled {
                    Button(intent: AddCigaretteIntent()) {
                        Label("Log cig", systemImage: "flame.fill")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }

            case .drinking:
                Text("\(snapshot.drinks)")
                    .font(.largeTitle.bold().monospacedDigit())
                Text(limitLine(current: snapshot.drinks, limit: snapshot.drinkLimit, enabled: snapshot.drinkingEnabled))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if snapshot.drinkingEnabled {
                    Button(intent: AddDrinkIntent()) {
                        Label("Log drink", systemImage: "wineglass.fill")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                }

            case .bathroom:
                HStack {
                    metricPill("U", snapshot.urineCount)
                    metricPill("S", snapshot.stoolCount)
                }
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    Button(intent: AddBathroomIntent(kind: .urine)) {
                        Text("Urine")
                            .font(.caption2.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    Button(intent: AddBathroomIntent(kind: .stool)) {
                        Text("Stool")
                            .font(.caption2.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

            case .weight:
                if let w = snapshot.weightLbs {
                    Text(String(format: "%.1f", w))
                        .font(.largeTitle.bold().monospacedDigit())
                    Text("lb")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("—")
                        .font(.largeTitle.bold())
                    Text("Tap to weigh in")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if let bmi = snapshot.bmi {
                    Text(String(format: "BMI %.1f", bmi))
                        .font(.caption.monospacedDigit())
                }

            case .workouts:
                Text("\(snapshot.workoutMinutes)")
                    .font(.largeTitle.bold().monospacedDigit())
                Text("minutes · \(snapshot.workoutCount) sessions")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text("Tap to add workout")
                    .font(.caption2.weight(.semibold))

            case .feelings:
                Text("\(snapshot.feelingCount)")
                    .font(.largeTitle.bold().monospacedDigit())
                if let last = snapshot.lastFeelingName {
                    Text(last)
                        .font(.caption)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Text("Tap to log feeling")
                    .font(.caption2.weight(.semibold))

            case .checklist:
                Text("\(snapshot.checklistTotal)")
                    .font(.largeTitle.bold().monospacedDigit())
                Text("FV \(snapshot.fatsAndVeggiesCount) · Fr \(snapshot.fruitCount) · M \(snapshot.miscCount)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text("Tap to add foods")
                    .font(.caption2.weight(.semibold))

            case .supplements:
                Text("\(snapshot.supplementDosesCompleted)/\(max(snapshot.supplementDosesTotal, 1))")
                    .font(.largeTitle.bold().monospacedDigit())
                ProgressView(value: snapshot.supplementFraction).tint(.mint)
                Spacer(minLength: 0)
                Button(intent: MarkNextSupplementIntent()) {
                    Label("Mark next", systemImage: "checkmark")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.mint)

            case .dailyStatus:
                VStack(alignment: .leading, spacing: 8) {
                    statusRow(title: "On plan", on: snapshot.followedPlan)
                    statusRow(title: "Ketosis", on: snapshot.ketosis)
                }
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    Button(intent: ToggleFollowedPlanIntent()) {
                        Text("Plan")
                            .font(.caption2.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    Button(intent: ToggleKetosisIntent()) {
                        Text("Keto")
                            .font(.caption2.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(4)
    }

    private func limitLine(current: Int, limit: Int, enabled: Bool) -> String {
        guard enabled else { return "Tracking off" }
        guard limit > 0 else { return "today" }
        return "of \(limit) max"
    }

    private func metricPill(_ label: String, _ value: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title.bold().monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func statusRow(title: String, on: Bool) -> some View {
        HStack {
            Text(title)
                .font(.caption)
            Spacer()
            Image(systemName: on ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(on ? .green : .secondary)
        }
    }
}
