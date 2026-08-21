import SwiftUI
import Charts

/// Every per-section report, in the same shape as the Trends feed: card chrome, one hero
/// number that answers the question, themed marks, a legend where two colours appear, and
/// a table toggle so no value is reachable only by reading a colour off a chart.
///
/// These replace loose stacks of metric rows and untinted charts. Data comes from the same
/// `ReportSnapshot` as before — only the presentation changed.

// MARK: - Shell

/// Standard wrapper: grouped background, inline title, consistent padding.
private struct ReportScreen<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                content
            }
            .padding()
        }
        .background(Color.onPlanGroupedBackground)
        .navigationTitle(title)
        .onPlanInlineNav()
    }
}

/// A card with no chart — a row of related figures. Used where the answer really is a set
/// of numbers rather than a shape over time.
private struct ReportStatsCard: View {
    let title: String
    let rows: [(String, String)]

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    if index > 0 { Divider() }
                    HStack {
                        Text(row.0)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(row.1)
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                    }
                    .frame(minHeight: 30)
                }
            }
        }
    }
}

/// Horizontal ranked bars — "top foods", "activities", "by type". One hue: the ranking is
/// already carried by bar length and order, so colour has no second job to do.
private struct RankedBarCard: View {
    let title: String
    let items: [NamedCount]
    let tint: Color
    var unit: String = ""

    var body: some View {
        if !items.isEmpty {
            TrendCard(
                title: title,
                heroValue: items.first.map { "\($0.count)" } ?? "0",
                heroCaption: items.first.map { "× \($0.name)" } ?? "",
                trailing: items.count > 1 ? "\(items.count) tracked" : nil
            ) {
                Chart(items) { item in
                    BarMark(
                        x: .value("Count", item.count),
                        y: .value("Item", item.name)
                    )
                    .foregroundStyle(tint)
                    .cornerRadius(3)
                }
                .trendAxes()
                .frame(height: CGFloat(max(120, items.count * 30)))
            } table: {
                TrendTable(rows: items.map { ($0.name, "\($0.count)\(unit)") })
            }
        }
    }
}

private struct ReportEmptyCard: View {
    var message = "Nothing logged in this range."

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("No data yet")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Bars for a per-day count, with an optional limit rule. Shared by smoking, drinking and
/// bathroom, which are the same chart with different nouns.
private struct DailyCountCard: View {
    let title: String
    let heroValue: String
    let heroCaption: String
    var trailing: String?
    let series: [DailyMetricPoint]
    let tint: Color
    var overTint: Color?
    var limit: Double?
    var limitLabel: String = "Max"
    var unit: String = ""

    var body: some View {
        TrendCard(
            title: title,
            heroValue: heroValue,
            heroCaption: heroCaption,
            trailing: trailing
        ) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                if series.isEmpty {
                    Text("Nothing logged in this range.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
                } else {
                    Chart {
                        ForEach(series) { point in
                            BarMark(
                                x: .value("Day", point.date, unit: .day),
                                y: .value(title, point.value)
                            )
                            .foregroundStyle(barColor(for: point.value))
                            .cornerRadius(2)
                        }
                        if let limit {
                            RuleMark(y: .value(limitLabel, limit))
                                .foregroundStyle(overTint ?? tint)
                                .lineStyle(StrokeStyle(lineWidth: 1.5))
                                .annotation(position: .top, alignment: .leading) {
                                    Text("\(limitLabel) \(Int(limit))")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(overTint ?? tint)
                                }
                        }
                    }
                    .trendAxes()
                    .frame(height: 130)

                    if let limit, let overTint {
                        ChartLegend(items: [
                            (tint, "At or under \(limitLabel.lowercased())  \(series.filter { $0.value <= limit }.count)"),
                            (overTint, "Over  \(series.filter { $0.value > limit }.count)")
                        ])
                    }
                }
            }
        } table: {
            TrendTable(rows: series.reversed().map { ($0.label, "\(Int($0.value))\(unit)") })
        }
    }

    private func barColor(for value: Double) -> Color {
        guard let limit, let overTint, value > limit else { return tint }
        return overTint
    }
}

/// A single measurement over time — fat %, waist, neck, BMI. Line plus endpoint, one hue.
private struct MeasurementTrendCard: View {
    let title: String
    let series: [DailyMetricPoint]
    let unit: String
    let tint: Color
    var goal: Double?
    var format: String = "%.1f"

    var body: some View {
        if series.count >= 2 {
            TrendCard(
                title: title,
                heroValue: series.last.map { String(format: format, $0.value) } ?? "—",
                heroCaption: unit,
                trailing: delta,
                trailingTint: (rawDelta ?? 0) < 0 ? .green : .secondary
            ) {
                Chart {
                    ForEach(series) { point in
                        LineMark(
                            x: .value("Day", point.date),
                            y: .value(title, point.value)
                        )
                        .foregroundStyle(tint)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.catmullRom)
                    }
                    if let last = series.last {
                        PointMark(
                            x: .value("Day", last.date),
                            y: .value(title, last.value)
                        )
                        .foregroundStyle(tint)
                        .symbolSize(70)
                    }
                    if let goal {
                        RuleMark(y: .value("Goal", goal))
                            .foregroundStyle(.secondary)
                            .lineStyle(StrokeStyle(lineWidth: 1))
                            .annotation(position: .top, alignment: .leading) {
                                Text("Goal \(String(format: format, goal))")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .chartYScale(domain: domain)
                .trendAxes(yPosition: .leading)
                .frame(height: 150)
                .clipped()
            } table: {
                TrendTable(rows: series.reversed().map {
                    ($0.label, String(format: "\(format) \(unit)", $0.value))
                })
            }
        }
    }

    private var rawDelta: Double? {
        guard let first = series.first?.value, let last = series.last?.value else { return nil }
        return last - first
    }

    private var delta: String? {
        guard let rawDelta else { return nil }
        return String(format: "%@\(format) \(unit) in range", rawDelta < 0 ? "−" : "+", abs(rawDelta))
    }

    /// Keep a nearly-flat series from filling the plot and reading as a dramatic swing.
    private var domain: ClosedRange<Double> {
        let values = series.map(\.value)
        guard let low = values.min(), let high = values.max() else { return 0...1 }
        let floorSpan = max(high * 0.06, 1)
        let span = max(high - low, floorSpan)
        let pad = (span - (high - low)) / 2 + span * 0.1
        return (low - pad)...(high + pad)
    }
}

// MARK: - Nutrition

struct ProteinReportView: View {
    let snapshot: ReportSnapshot
    @Environment(\.appTheme) private var appTheme

    private var goal: Double { snapshot.avgProteinGoal }

    var body: some View {
        ReportScreen(title: "Protein") {
            if snapshot.proteinSeries.isEmpty {
                ReportEmptyCard()
            } else {
                TrendCard(
                    title: "Daily protein vs goal",
                    heroValue: "\(snapshot.daysOnProteinGoal)",
                    heroCaption: "of \(snapshot.logs.count) days at or under goal",
                    trailing: "avg \(Int(snapshot.avgProteinCalories.rounded()))"
                ) {
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        Chart {
                            ForEach(snapshot.proteinSeries) { point in
                                BarMark(
                                    x: .value("Day", point.date, unit: .day),
                                    y: .value("kcal", point.value)
                                )
                                .foregroundStyle(point.value > goal ? appTheme.warn : appTheme.protein)
                                .cornerRadius(2)
                            }
                            RuleMark(y: .value("Goal", goal))
                                .foregroundStyle(appTheme.warn)
                                .lineStyle(StrokeStyle(lineWidth: 1.5))
                                .annotation(position: .top, alignment: .leading) {
                                    Text("Goal \(Int(goal.rounded())) kcal")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(appTheme.warn)
                                }
                        }
                        .trendAxes()
                        .frame(height: 150)

                        ChartLegend(items: [
                            (appTheme.protein, "At or under goal  \(snapshot.daysOnProteinGoal)"),
                            (appTheme.warn, "Over  \(snapshot.daysOverProteinGoal)")
                        ])
                    }
                } table: {
                    TrendTable(rows: snapshot.proteinSeries.reversed().map {
                        ($0.label, "\(Int($0.value)) kcal")
                    })
                }

                RankedBarCard(title: "Top foods", items: snapshot.topProteins, tint: appTheme.protein)
            }
        }
    }
}

struct ChecklistReportView: View {
    let snapshot: ReportSnapshot
    @Environment(\.appTheme) private var appTheme

    private var isEmpty: Bool {
        snapshot.vegetableCounts.isEmpty
            && snapshot.fatCounts.isEmpty
            && snapshot.fruitCounts.isEmpty
            && snapshot.miscCounts.isEmpty
    }

    var body: some View {
        ReportScreen(title: "Fats & veggies") {
            if isEmpty {
                ReportEmptyCard()
            } else {
                if !snapshot.veggiesPerDay.isEmpty {
                    TrendCard(
                        title: "Vegetable items per day",
                        heroValue: String(format: "%.1f", snapshot.avgVeggiesPerDay),
                        heroCaption: "average per logged day",
                        trailing: "\(snapshot.logs.count) days"
                    ) {
                        Chart(snapshot.veggiesPerDay) { point in
                            BarMark(
                                x: .value("Day", point.date, unit: .day),
                                y: .value("Items", point.value)
                            )
                            .foregroundStyle(appTheme.ok)
                            .cornerRadius(2)
                        }
                        .trendAxes()
                        .frame(height: 130)
                    } table: {
                        TrendTable(rows: snapshot.veggiesPerDay.reversed().map {
                            ($0.label, "\(Int($0.value))")
                        })
                    }
                }

                RankedBarCard(title: "Top vegetables", items: snapshot.vegetableCounts, tint: appTheme.ok)
                RankedBarCard(title: "Top fats", items: snapshot.fatCounts, tint: appTheme.warn)
                RankedBarCard(title: "Top fruits", items: snapshot.fruitCounts, tint: appTheme.protein)
                RankedBarCard(title: "Top misc", items: snapshot.miscCounts, tint: appTheme.water)
            }
        }
    }
}

struct HydrationReportView: View {
    let snapshot: ReportSnapshot
    @Environment(\.appTheme) private var appTheme

    private var target: Double { snapshot.hydrationTarget }

    var body: some View {
        ReportScreen(title: "Hydration") {
            if snapshot.hydrationSeries.isEmpty {
                ReportEmptyCard()
            } else {
                TrendCard(
                    title: "Daily intake",
                    heroValue: "\(Int(snapshot.avgWaterOz.rounded()))",
                    heroCaption: "oz average per day",
                    trailing: "\(snapshot.daysAtHydrationTarget) of \(snapshot.logs.count) at target"
                ) {
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        Chart {
                            ForEach(snapshot.hydrationSeries) { point in
                                BarMark(
                                    x: .value("Day", point.date, unit: .day),
                                    y: .value("oz", point.value)
                                )
                                .foregroundStyle(point.value >= target ? appTheme.water : appTheme.water.opacity(0.32))
                                .cornerRadius(2)
                            }
                            RuleMark(y: .value("Target", target))
                                .foregroundStyle(appTheme.water)
                                .lineStyle(StrokeStyle(lineWidth: 1.5))
                                .annotation(position: .top, alignment: .leading) {
                                    Text("Target \(Int(target)) oz")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(appTheme.water)
                                }
                        }
                        .trendAxes()
                        .frame(height: 150)

                        ChartLegend(items: [
                            (appTheme.water, "Hit target  \(snapshot.daysAtHydrationTarget)"),
                            (appTheme.water.opacity(0.32), "Short  \(snapshot.logs.count - snapshot.daysAtHydrationTarget)")
                        ])
                    }
                } table: {
                    TrendTable(rows: snapshot.hydrationSeries.reversed().map {
                        ($0.label, "\(Int($0.value)) oz")
                    })
                }
            }
        }
    }
}

struct SupplementsReportView: View {
    let snapshot: ReportSnapshot
    @Environment(\.appTheme) private var appTheme

    var body: some View {
        ReportScreen(title: "Supplements") {
            if snapshot.supplementAdherence.isEmpty {
                ReportEmptyCard()
            } else {
                TrendCard(
                    title: "Adherence",
                    heroValue: String(format: "%.0f%%", overall),
                    heroCaption: "of doses taken",
                    trailing: "\(snapshot.supplementAdherence.count) tracked"
                ) {
                    Chart(snapshot.supplementAdherence) { item in
                        BarMark(
                            x: .value("Adherence", item.percent),
                            y: .value("Supplement", item.name)
                        )
                        .foregroundStyle(item.percent >= 80 ? appTheme.ok : appTheme.warn)
                        .cornerRadius(3)
                    }
                    .chartXScale(domain: 0...100)
                    .trendAxes()
                    .frame(height: CGFloat(max(120, snapshot.supplementAdherence.count * 30)))
                } table: {
                    TrendTable(rows: snapshot.supplementAdherence.map {
                        ($0.name, "\($0.completed)/\($0.possible) · \(Int($0.percent))%")
                    })
                }
            }
        }
    }

    private var overall: Double {
        let possible = snapshot.supplementAdherence.reduce(0) { $0 + $1.possible }
        guard possible > 0 else { return 0 }
        let completed = snapshot.supplementAdherence.reduce(0) { $0 + $1.completed }
        return Double(completed) / Double(possible) * 100
    }
}

// MARK: - Body

struct WeightReportView: View {
    let snapshot: ReportSnapshot
    @Environment(\.appTheme) private var appTheme

    private var unit: String { snapshot.settings.usesMetricWeight ? "kg" : "lb" }

    var body: some View {
        ReportScreen(title: "Weight & BMI") {
            if snapshot.weightSeries.isEmpty {
                ReportEmptyCard(message: "Log a weigh-in and the trend starts here.")
            } else {
                MeasurementTrendCard(
                    title: "Weight",
                    series: snapshot.weightSeries,
                    unit: unit,
                    tint: appTheme.tint,
                    goal: snapshot.goalWeightDisplay
                )

                MeasurementTrendCard(
                    title: "BMI",
                    series: snapshot.bmiSeries,
                    unit: "",
                    tint: appTheme.weight,
                    goal: snapshot.goalBMI
                )

                ReportStatsCard(title: "Over this range", rows: stats)
            }
        }
    }

    private var stats: [(String, String)] {
        var rows: [(String, String)] = []
        if let start = snapshot.weightSeries.first {
            rows.append(("Start", String(format: "%.1f %@", start.value, unit)))
        }
        if let latest = snapshot.latestWeightDisplay {
            rows.append(("Latest", String(format: "%.1f %@", latest, unit)))
        }
        if let delta = snapshot.weightDelta {
            rows.append(("Change", String(format: "%@%.1f %@", delta >= 0 ? "+" : "−", abs(delta), unit)))
        }
        if let goal = snapshot.goalWeightDisplay {
            rows.append(("Goal", String(format: "%.1f %@", goal, unit)))
        }
        if let toGo = snapshot.weightToGoDisplay {
            rows.append(("Vs goal", Self.toGoLabel(toGo, unit: unit)))
        }
        if let bmi = snapshot.latestBMI {
            rows.append(("Latest BMI", String(format: "%.1f (%@)", bmi, BMICalculator.category(for: bmi))))
        }
        rows.append(("Weigh-ins", "\(snapshot.weights.count)"))
        return rows
    }

    private static func toGoLabel(_ toGo: Double, unit: String) -> String {
        if abs(toGo) < 0.05 { return "At goal" }
        if toGo > 0 { return String(format: "%.1f %@ to go", toGo, unit) }
        return String(format: "%.1f %@ under goal", abs(toGo), unit)
    }
}

struct BodyCompositionReportView: View {
    let snapshot: ReportSnapshot
    @Environment(\.appTheme) private var appTheme

    private var unit: String { snapshot.settings.usesMetricWeight ? "kg" : "lb" }

    var body: some View {
        ReportScreen(title: "Body composition") {
            if snapshot.bodyCompositions.isEmpty {
                ReportEmptyCard(message: "Add a body-composition reading to see it trend.")
            } else {
                MeasurementTrendCard(
                    title: "Body fat",
                    series: snapshot.fatPercentSeries,
                    unit: "%",
                    tint: appTheme.warn
                )

                MeasurementTrendCard(
                    title: "Weight",
                    series: snapshot.bodyCompWeightSeries,
                    unit: unit,
                    tint: appTheme.tint,
                    goal: snapshot.goalWeightDisplay
                )

                ReportStatsCard(title: "Latest reading", rows: stats)
            }
        }
    }

    private var stats: [(String, String)] {
        var rows: [(String, String)] = [("Readings", "\(snapshot.bodyCompositions.count)")]
        if let fat = snapshot.latestFatPercent {
            rows.append(("Fat %", String(format: "%.1f%%", fat)))
        }
        if let bmi = snapshot.latestBodyCompBMI {
            rows.append(("BMI", String(format: "%.1f (%@)", bmi, BMICalculator.category(for: bmi))))
        }
        if let weight = snapshot.latestBodyCompWeightDisplay {
            rows.append(("Weight", String(format: "%.1f %@", weight, unit)))
        }
        if let fatMass = snapshot.latestFatMassDisplay {
            rows.append(("Fat mass", String(format: "%.1f %@", fatMass, unit)))
        }
        return rows
    }
}

struct TapeMeasurementsReportView: View {
    let snapshot: ReportSnapshot
    @Environment(\.appTheme) private var appTheme

    private var unit: String { snapshot.settings.usesMetricWeight ? "cm" : "in" }

    var body: some View {
        ReportScreen(title: "Tape measurements") {
            if snapshot.measurements.isEmpty {
                ReportEmptyCard(message: "Record a tape session to see it trend.")
            } else {
                MeasurementTrendCard(
                    title: "Waist",
                    series: snapshot.waistSeries,
                    unit: unit,
                    tint: appTheme.tint
                )

                MeasurementTrendCard(
                    title: "Neck",
                    series: snapshot.neckSeries,
                    unit: unit,
                    tint: appTheme.water
                )

                ReportStatsCard(title: "Latest", rows: stats)
            }
        }
    }

    private var stats: [(String, String)] {
        var rows: [(String, String)] = [("Sessions", "\(snapshot.measurements.count)")]
        if let waist = snapshot.latestWaistDisplay {
            rows.append(("Waist", String(format: "%.1f %@", waist, unit)))
        }
        if let summary = snapshot.latestMeasurementSummary {
            rows.append(("Summary", summary))
        }
        return rows
    }
}

// MARK: - Activity & habits

struct WorkoutReportView: View {
    let snapshot: ReportSnapshot
    @Environment(\.appTheme) private var appTheme

    var body: some View {
        ReportScreen(title: "Workouts") {
            if snapshot.totalWorkoutSessions == 0 {
                ReportEmptyCard(message: "No workouts logged in this range.")
            } else {
                DailyCountCard(
                    title: "Minutes per day",
                    heroValue: "\(snapshot.totalWorkoutMinutes)",
                    heroCaption: "minutes total",
                    trailing: "\(snapshot.totalWorkoutSessions) sessions",
                    series: snapshot.workoutMinutesSeries,
                    tint: appTheme.ok,
                    unit: " min"
                )

                RankedBarCard(title: "Activities", items: snapshot.workoutActivityCounts, tint: appTheme.ok)
            }
        }
    }
}

struct SmokingReportView: View {
    let snapshot: ReportSnapshot
    @Environment(\.appTheme) private var appTheme

    var body: some View {
        ReportScreen(title: "Smoking") {
            DailyCountCard(
                title: "Daily count",
                heroValue: "\(snapshot.smokeFreeDaysInRange)",
                heroCaption: "of \(snapshot.logs.count) days smoke-free",
                trailing: String(format: "avg %.1f / day", snapshot.avgCigarettesPerDay),
                series: snapshot.cigaretteSeries,
                tint: appTheme.tint,
                overTint: appTheme.danger,
                limit: snapshot.settings.effectiveDailyCigaretteLimit.map(Double.init),
                limitLabel: "Max"
            )

            ReportStatsCard(title: "Over this range", rows: stats)
        }
    }

    private var stats: [(String, String)] {
        var rows: [(String, String)] = [
            ("Mode", snapshot.settings.smokingMode.title),
            ("Total cigarettes", "\(snapshot.totalCigarettes)"),
            ("Smoke-free days", "\(snapshot.smokeFreeDaysInRange)/\(snapshot.logs.count)")
        ]
        if snapshot.settings.effectiveDailyCigaretteLimit != nil {
            rows.append(("Days at/under max", "\(snapshot.daysUnderCigaretteLimit)/\(snapshot.logs.count)"))
        }
        if snapshot.totalUrges > 0 {
            rows.append(("Urges logged", "\(snapshot.totalUrges)"))
        }
        return rows
    }
}

struct DrinkingReportView: View {
    let snapshot: ReportSnapshot
    @Environment(\.appTheme) private var appTheme

    var body: some View {
        ReportScreen(title: "Drinking") {
            DailyCountCard(
                title: "Daily drinks",
                heroValue: "\(snapshot.alcoholFreeDaysInRange)",
                heroCaption: "of \(snapshot.logs.count) days alcohol-free",
                trailing: String(format: "avg %.1f / day", snapshot.avgDrinksPerDay),
                series: snapshot.drinkSeries,
                tint: appTheme.tint,
                overTint: appTheme.danger,
                limit: snapshot.settings.effectiveDailyDrinkLimit.map(Double.init),
                limitLabel: "Max"
            )

            ReportStatsCard(title: "Over this range", rows: stats)
        }
    }

    private var stats: [(String, String)] {
        var rows: [(String, String)] = [
            ("Mode", snapshot.settings.drinkingMode.title),
            ("Total drinks", "\(snapshot.totalDrinks)"),
            ("Alcohol-free days", "\(snapshot.alcoholFreeDaysInRange)/\(snapshot.logs.count)")
        ]
        if snapshot.settings.effectiveDailyDrinkLimit != nil {
            rows.append(("Days at/under max", "\(snapshot.daysUnderDrinkLimit)/\(snapshot.logs.count)"))
        }
        if snapshot.totalDrinkUrges > 0 {
            rows.append(("Urges logged", "\(snapshot.totalDrinkUrges)"))
        }
        return rows
    }
}

// MARK: - Wellbeing

struct FeelingsReportView: View {
    let snapshot: ReportSnapshot
    @Environment(\.appTheme) private var appTheme

    var body: some View {
        ReportScreen(title: "Feelings") {
            if snapshot.totalFeelings == 0 {
                ReportEmptyCard(message: "No feelings or cravings logged in this range.")
            } else {
                DailyCountCard(
                    title: "Events per day",
                    heroValue: "\(snapshot.totalFeelings)",
                    heroCaption: "logged in total",
                    trailing: String(format: "avg %.1f / day", snapshot.avgFeelingsPerDay),
                    series: snapshot.feelingsPerDay,
                    tint: appTheme.protein
                )

                RankedBarCard(title: "By type", items: snapshot.feelingCounts, tint: appTheme.protein)
            }
        }
    }
}

struct BathroomReportView: View {
    let snapshot: ReportSnapshot
    @Environment(\.appTheme) private var appTheme

    var body: some View {
        ReportScreen(title: "Bathroom") {
            if snapshot.totalUrine == 0 && snapshot.totalStool == 0 {
                ReportEmptyCard()
            } else {
                if snapshot.totalUrine > 0 {
                    DailyCountCard(
                        title: "Urine per day",
                        heroValue: "\(snapshot.totalUrine)",
                        heroCaption: "logged in total",
                        trailing: "\(snapshot.daysWithBathroomLog) of \(snapshot.logs.count) days logged",
                        series: snapshot.urineSeries,
                        tint: appTheme.water
                    )
                }
                if snapshot.totalStool > 0 {
                    DailyCountCard(
                        title: "Stool per day",
                        heroValue: "\(snapshot.totalStool)",
                        heroCaption: "logged in total",
                        series: snapshot.stoolSeries,
                        tint: appTheme.warn
                    )
                }
            }
        }
    }
}
