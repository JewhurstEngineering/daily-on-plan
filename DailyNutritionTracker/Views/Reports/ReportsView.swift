import SwiftUI
import Charts

struct ReportsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var range: ReportRange = .days30
    @State private var endDate = Date()
    @State private var customStart = Calendar.current.date(byAdding: .day, value: -13, to: Date()) ?? Date()
    @State private var snapshot: ReportSnapshot?

    var body: some View {
        NavigationStack {
            List {
                Section("Range") {
                    Picker("Range", selection: $range) {
                        ForEach(ReportRange.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if range == .custom {
                        DatePicker("From", selection: $customStart, in: ...endDate, displayedComponents: .date)
                        DatePicker("To", selection: $endDate, displayedComponents: .date)
                    }
                    if let snapshot {
                        Text("\(snapshot.logs.count) days logged · \(snapshot.start.formatted(.dateTime.month().day())) – \(snapshot.end.formatted(.dateTime.month().day()))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Overview") {
                    NavigationLink {
                        SnapshotReportView(snapshot: currentSnapshot)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Snapshot", systemImage: "chart.bar.doc.horizontal")
                            Text("Average day + weekly rollups for this range")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    NavigationLink {
                        CalendarHeatmapView(snapshot: currentSnapshot)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Calendar heatmap", systemImage: "calendar")
                            Text("Plan, water, protein, and habit free days")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Section reports") {
                    NavigationLink {
                        FeelingsReportView(snapshot: currentSnapshot)
                    } label: {
                        Label("Feelings & Cravings", systemImage: "heart.text.square")
                    }
                    NavigationLink {
                        ProteinReportView(snapshot: currentSnapshot)
                    } label: {
                        Label("Protein", systemImage: "fork.knife.circle")
                    }
                    NavigationLink {
                        ChecklistReportView(snapshot: currentSnapshot)
                    } label: {
                        Label("Fats, Veggies & More", systemImage: "leaf")
                    }
                    NavigationLink {
                        WorkoutReportView(snapshot: currentSnapshot)
                    } label: {
                        Label("Workouts", systemImage: "figure.run")
                    }
                    NavigationLink {
                        HydrationReportView(snapshot: currentSnapshot)
                    } label: {
                        Label("Hydration", systemImage: "drop.fill")
                    }
                    NavigationLink {
                        WeightReportView(snapshot: currentSnapshot)
                    } label: {
                        Label("Weight & BMI", systemImage: "scalemass")
                    }
                    if currentSnapshot.showsSmokingReport {
                        NavigationLink {
                            SmokingReportView(snapshot: currentSnapshot)
                        } label: {
                            Label("Smoking", systemImage: "smoke")
                        }
                    }
                    if currentSnapshot.showsDrinkingReport {
                        NavigationLink {
                            DrinkingReportView(snapshot: currentSnapshot)
                        } label: {
                            Label("Drinking", systemImage: "wineglass")
                        }
                    }
                    NavigationLink {
                        SupplementsReportView(snapshot: currentSnapshot)
                    } label: {
                        Label("Supplements", systemImage: "pills")
                    }
                }
            }
            .navigationTitle("Reports")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear { refresh() }
            .onChange(of: range) { _, _ in refresh() }
            .onChange(of: endDate) { _, _ in refresh() }
            .onChange(of: customStart) { _, _ in refresh() }
        }
    }

    private var currentSnapshot: ReportSnapshot {
        snapshot ?? ReportAggregator.snapshot(
            range: range,
            endDate: endDate,
            customStart: customStart,
            in: modelContext
        )
    }

    private func refresh() {
        snapshot = ReportAggregator.snapshot(
            range: range,
            endDate: endDate,
            customStart: customStart,
            in: modelContext
        )
    }
}

// MARK: - Shared report chrome

struct ReportMetricRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .font(.subheadline)
    }
}

struct EmptyReportHint: View {
    var body: some View {
        ContentUnavailableView(
            "No data in range",
            systemImage: "chart.bar",
            description: Text("Log a few days, then reopen reports.")
        )
    }
}

// MARK: - Section reports

struct FeelingsReportView: View {
    let snapshot: ReportSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ReportMetricRow(title: "Total events", value: "\(snapshot.totalFeelings)")
                ReportMetricRow(
                    title: "Avg / logged day",
                    value: snapshot.logs.isEmpty
                        ? "0"
                        : String(format: "%.1f", Double(snapshot.totalFeelings) / Double(snapshot.logs.count))
                )
                if let top = snapshot.feelingCounts.first {
                    ReportMetricRow(title: "Most common", value: "\(top.name) (\(top.count))")
                }

                if !snapshot.feelingCounts.isEmpty {
                    Text("By type")
                        .font(.headline)
                    Chart(snapshot.feelingCounts) { item in
                        BarMark(
                            x: .value("Count", item.count),
                            y: .value("Type", item.name)
                        )
                        .foregroundStyle(Color.accentColor)
                    }
                    .frame(height: CGFloat(max(160, snapshot.feelingCounts.count * 36)))
                }

                if !snapshot.feelingsPerDay.isEmpty {
                    Text("Events per day")
                        .font(.headline)
                    Chart(snapshot.feelingsPerDay) { point in
                        LineMark(
                            x: .value("Day", point.date),
                            y: .value("Events", point.value)
                        )
                        PointMark(
                            x: .value("Day", point.date),
                            y: .value("Events", point.value)
                        )
                    }
                    .frame(height: 180)
                }

                if snapshot.totalFeelings == 0 {
                    EmptyReportHint()
                }
            }
            .padding()
        }
        .navigationTitle("Feelings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ProteinReportView: View {
    let snapshot: ReportSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ReportMetricRow(title: "Avg protein kcal", value: String(format: "%.0f", snapshot.avgProteinCalories))
                ReportMetricRow(title: "Days over goal", value: "\(snapshot.daysOverProteinGoal)")
                ReportMetricRow(title: "Logged days", value: "\(snapshot.logs.count)")

                if !snapshot.proteinSeries.isEmpty {
                    Text("Daily protein vs goal")
                        .font(.headline)
                    Chart {
                        ForEach(snapshot.proteinSeries) { point in
                            LineMark(
                                x: .value("Day", point.date),
                                y: .value("kcal", point.value),
                                series: .value("Series", "Actual")
                            )
                            .foregroundStyle(Color.accentColor)
                            PointMark(
                                x: .value("Day", point.date),
                                y: .value("kcal", point.value)
                            )
                            .foregroundStyle(Color.accentColor)
                        }
                        ForEach(snapshot.proteinGoalSeries) { point in
                            LineMark(
                                x: .value("Day", point.date),
                                y: .value("kcal", point.value),
                                series: .value("Series", "Goal")
                            )
                            .foregroundStyle(.orange)
                            .lineStyle(StrokeStyle(dash: [4, 3]))
                        }
                    }
                    .frame(height: 200)
                }

                if !snapshot.topProteins.isEmpty {
                    Text("Top foods")
                        .font(.headline)
                    Chart(snapshot.topProteins) { item in
                        BarMark(
                            x: .value("Count", item.count),
                            y: .value("Food", item.name)
                        )
                    }
                    .frame(height: CGFloat(max(160, snapshot.topProteins.count * 28)))
                }

                if snapshot.logs.isEmpty {
                    EmptyReportHint()
                }
            }
            .padding()
        }
        .navigationTitle("Protein")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ChecklistReportView: View {
    let snapshot: ReportSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !snapshot.veggiesPerDay.isEmpty {
                    Text("Vegetable items / day")
                        .font(.headline)
                    Chart(snapshot.veggiesPerDay) { point in
                        BarMark(
                            x: .value("Day", point.date),
                            y: .value("Count", point.value)
                        )
                        .foregroundStyle(Color.accentColor)
                    }
                    .frame(height: 180)
                }

                categoryBlock(title: "Top vegetables", items: snapshot.vegetableCounts)
                categoryBlock(title: "Top fats", items: snapshot.fatCounts)
                categoryBlock(title: "Top fruits", items: snapshot.fruitCounts)
                categoryBlock(title: "Top misc", items: snapshot.miscCounts)

                if snapshot.vegetableCounts.isEmpty
                    && snapshot.fatCounts.isEmpty
                    && snapshot.fruitCounts.isEmpty
                    && snapshot.miscCounts.isEmpty {
                    EmptyReportHint()
                }
            }
            .padding()
        }
        .navigationTitle("Fats & Veggies")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func categoryBlock(title: String, items: [NamedCount]) -> some View {
        if !items.isEmpty {
            Text(title)
                .font(.headline)
            Chart(items) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("Item", item.name)
                )
            }
            .frame(height: CGFloat(max(120, items.count * 28)))
        }
    }
}

struct WorkoutReportView: View {
    let snapshot: ReportSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ReportMetricRow(title: "Total minutes", value: "\(snapshot.totalWorkoutMinutes)")
                ReportMetricRow(title: "Sessions", value: "\(snapshot.totalWorkoutSessions)")

                if !snapshot.workoutMinutesSeries.isEmpty {
                    Text("Minutes per day")
                        .font(.headline)
                    Chart(snapshot.workoutMinutesSeries) { point in
                        BarMark(
                            x: .value("Day", point.date),
                            y: .value("Minutes", point.value)
                        )
                        .foregroundStyle(Color.accentColor)
                    }
                    .frame(height: 180)
                }

                if !snapshot.workoutActivityCounts.isEmpty {
                    Text("Activities")
                        .font(.headline)
                    Chart(snapshot.workoutActivityCounts) { item in
                        BarMark(
                            x: .value("Count", item.count),
                            y: .value("Activity", item.name)
                        )
                    }
                    .frame(height: CGFloat(max(140, snapshot.workoutActivityCounts.count * 28)))
                }

                if snapshot.totalWorkoutSessions == 0 {
                    EmptyReportHint()
                }
            }
            .padding()
        }
        .navigationTitle("Workouts")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HydrationReportView: View {
    let snapshot: ReportSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ReportMetricRow(title: "Target", value: "\(Int(snapshot.hydrationTarget)) oz")
                ReportMetricRow(title: "Days at target", value: "\(snapshot.daysAtHydrationTarget)/\(snapshot.logs.count)")

                if !snapshot.hydrationSeries.isEmpty {
                    Text("Daily intake")
                        .font(.headline)
                    Chart {
                        ForEach(snapshot.hydrationSeries) { point in
                            LineMark(
                                x: .value("Day", point.date),
                                y: .value("oz", point.value)
                            )
                            .foregroundStyle(Color.accentColor)
                            PointMark(
                                x: .value("Day", point.date),
                                y: .value("oz", point.value)
                            )
                        }
                        RuleMark(y: .value("Target", snapshot.hydrationTarget))
                            .foregroundStyle(.orange)
                            .lineStyle(StrokeStyle(dash: [4, 3]))
                            .annotation(position: .top, alignment: .trailing) {
                                Text("Target")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                    }
                    .frame(height: 200)
                } else {
                    EmptyReportHint()
                }
            }
            .padding()
        }
        .navigationTitle("Hydration")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct WeightReportView: View {
    let snapshot: ReportSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                let unit = snapshot.settings.usesMetricWeight ? "kg" : "lb"
                if let delta = snapshot.weightDelta {
                    ReportMetricRow(
                        title: "Change over range",
                        value: String(format: "%@%.1f %@", delta >= 0 ? "+" : "", delta, unit)
                    )
                }
                if let goal = snapshot.goalWeightDisplay {
                    ReportMetricRow(title: "Goal weight", value: String(format: "%.1f %@", goal, unit))
                }
                if let latest = snapshot.latestWeightDisplay {
                    ReportMetricRow(title: "Latest weight", value: String(format: "%.1f %@", latest, unit))
                }
                if let toGo = snapshot.weightToGoDisplay {
                    ReportMetricRow(title: "Vs goal", value: Self.weightToGoLabel(toGo, unit: unit))
                }
                if let bmi = snapshot.latestBMI {
                    ReportMetricRow(
                        title: "Latest BMI",
                        value: String(format: "%.1f (%@)", bmi, BMICalculator.category(for: bmi))
                    )
                }
                ReportMetricRow(title: "Weigh-ins", value: "\(snapshot.weights.count)")

                if !snapshot.weightSeries.isEmpty {
                    Text("Trend")
                        .font(.headline)
                    Chart {
                        ForEach(snapshot.weightSeries) { point in
                            LineMark(
                                x: .value("Day", point.date),
                                y: .value("Weight", point.value)
                            )
                            PointMark(
                                x: .value("Day", point.date),
                                y: .value("Weight", point.value)
                            )
                        }
                        if let goal = snapshot.goalWeightDisplay {
                            RuleMark(y: .value("Goal", goal))
                                .foregroundStyle(.orange)
                                .lineStyle(StrokeStyle(dash: [4, 3]))
                                .annotation(position: .top, alignment: .trailing) {
                                    Text("Goal")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }
                        }
                    }
                    .frame(height: 200)
                    .chartYAxisLabel(unit)
                } else {
                    EmptyReportHint()
                }
            }
            .padding()
        }
        .navigationTitle("Weight & BMI")
        .navigationBarTitleDisplayMode(.inline)
    }

    private static func weightToGoLabel(_ toGo: Double, unit: String) -> String {
        if abs(toGo) < 0.05 { return "At goal" }
        if toGo > 0 { return String(format: "%.1f %@ to go", toGo, unit) }
        return String(format: "%.1f %@ under goal", abs(toGo), unit)
    }
}

struct SmokingReportView: View {
    let snapshot: ReportSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ReportMetricRow(title: "Mode", value: snapshot.settings.smokingMode.title)
                ReportMetricRow(title: "Total cigarettes", value: "\(snapshot.totalCigarettes)")
                ReportMetricRow(
                    title: "Avg / day",
                    value: String(format: "%.1f", snapshot.avgCigarettesPerDay)
                )
                ReportMetricRow(
                    title: "Smoke-free days",
                    value: "\(snapshot.smokeFreeDaysInRange)/\(snapshot.logs.count)"
                )
                if snapshot.settings.effectiveDailyCigaretteLimit != nil {
                    ReportMetricRow(
                        title: "Days at/under max",
                        value: "\(snapshot.daysUnderCigaretteLimit)/\(snapshot.logs.count)"
                    )
                }
                if snapshot.totalUrges > 0 {
                    ReportMetricRow(title: "Urges logged", value: "\(snapshot.totalUrges)")
                }

                if !snapshot.cigaretteSeries.isEmpty {
                    Text("Daily count")
                        .font(.headline)
                    Chart {
                        ForEach(snapshot.cigaretteSeries) { point in
                            BarMark(
                                x: .value("Day", point.date),
                                y: .value("Cigs", point.value)
                            )
                            .foregroundStyle(Color.accentColor)
                        }
                        if let limit = snapshot.settings.effectiveDailyCigaretteLimit {
                            RuleMark(y: .value("Max", Double(limit)))
                                .foregroundStyle(.orange)
                                .lineStyle(StrokeStyle(dash: [4, 3]))
                        }
                    }
                    .frame(height: 200)
                } else {
                    EmptyReportHint()
                }
            }
            .padding()
        }
        .navigationTitle("Smoking")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DrinkingReportView: View {
    let snapshot: ReportSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ReportMetricRow(title: "Mode", value: snapshot.settings.drinkingMode.title)
                ReportMetricRow(title: "Total drinks", value: "\(snapshot.totalDrinks)")
                ReportMetricRow(
                    title: "Avg / day",
                    value: String(format: "%.1f", snapshot.avgDrinksPerDay)
                )
                ReportMetricRow(
                    title: "Alcohol-free days",
                    value: "\(snapshot.alcoholFreeDaysInRange)/\(snapshot.logs.count)"
                )
                if snapshot.settings.effectiveDailyDrinkLimit != nil {
                    ReportMetricRow(
                        title: "Days at/under max",
                        value: "\(snapshot.daysUnderDrinkLimit)/\(snapshot.logs.count)"
                    )
                }
                if snapshot.totalDrinkUrges > 0 {
                    ReportMetricRow(title: "Urges logged", value: "\(snapshot.totalDrinkUrges)")
                }

                if !snapshot.drinkSeries.isEmpty {
                    Text("Daily drinks")
                        .font(.headline)
                    Chart {
                        ForEach(snapshot.drinkSeries) { point in
                            BarMark(
                                x: .value("Day", point.date),
                                y: .value("Drinks", point.value)
                            )
                            .foregroundStyle(Color.accentColor)
                        }
                        if let limit = snapshot.settings.effectiveDailyDrinkLimit {
                            RuleMark(y: .value("Max", Double(limit)))
                                .foregroundStyle(.orange)
                                .lineStyle(StrokeStyle(dash: [4, 3]))
                        }
                    }
                    .frame(height: 200)
                } else {
                    EmptyReportHint()
                }
            }
            .padding()
        }
        .navigationTitle("Drinking")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SupplementsReportView: View {
    let snapshot: ReportSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if snapshot.supplementAdherence.isEmpty {
                    EmptyReportHint()
                } else {
                    ForEach(snapshot.supplementAdherence) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(item.name)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(String(format: "%.0f%%", item.percent))
                                    .monospacedDigit()
                            }
                            ProgressView(value: min(item.percent / 100, 1))
                            Text("\(item.completed)/\(item.possible) doses")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }

                    Chart(snapshot.supplementAdherence) { item in
                        BarMark(
                            x: .value("Adherence", item.percent),
                            y: .value("Supplement", item.name)
                        )
                        .foregroundStyle(Color.accentColor)
                    }
                    .frame(height: CGFloat(max(160, snapshot.supplementAdherence.count * 32)))
                }
            }
            .padding()
        }
        .navigationTitle("Supplements")
        .navigationBarTitleDisplayMode(.inline)
    }
}
