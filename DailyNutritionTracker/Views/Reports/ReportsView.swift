import SwiftUI
import Charts

struct ReportsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var showsCloseButton: Bool = true

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

                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.m) {
                            ReportMarqueeCard(
                                title: "What I’ve Been Eating",
                                subtitle: "Day-by-day food & drink",
                                systemImage: "list.bullet.rectangle"
                            ) {
                                EatingReportView(snapshot: currentSnapshot)
                            }
                            ReportMarqueeCard(
                                title: "Snapshot",
                                subtitle: "Average day + weekly rollups",
                                systemImage: "chart.bar.doc.horizontal"
                            ) {
                                SnapshotReportView(snapshot: currentSnapshot)
                            }
                            ReportMarqueeCard(
                                title: "Calendar heatmap",
                                subtitle: "Plan, water, protein & habit-free days",
                                systemImage: "calendar"
                            ) {
                                CalendarHeatmapView(snapshot: currentSnapshot)
                            }
                        }
                        .padding(.vertical, Spacing.xs)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                } header: {
                    Text("Overview")
                }

                Section("Nutrition") {
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
                        HydrationReportView(snapshot: currentSnapshot)
                    } label: {
                        Label("Hydration", systemImage: "drop.fill")
                    }
                    NavigationLink {
                        SupplementsReportView(snapshot: currentSnapshot)
                    } label: {
                        Label("Supplements", systemImage: "pills")
                    }
                }

                Section("Body") {
                    NavigationLink {
                        WeightReportView(snapshot: currentSnapshot)
                    } label: {
                        Label("Weight & BMI", systemImage: "scalemass")
                    }
                    NavigationLink {
                        BodyCompositionReportView(snapshot: currentSnapshot)
                    } label: {
                        Label("Body composition", systemImage: "figure.arms.open")
                    }
                    NavigationLink {
                        TapeMeasurementsReportView(snapshot: currentSnapshot)
                    } label: {
                        Label("Tape measurements", systemImage: "ruler")
                    }
                }

                Section("Activity & Habits") {
                    NavigationLink {
                        WorkoutReportView(snapshot: currentSnapshot)
                    } label: {
                        Label("Workouts", systemImage: "figure.run")
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
                }

                Section("Wellbeing") {
                    NavigationLink {
                        FeelingsReportView(snapshot: currentSnapshot)
                    } label: {
                        Label("Feelings & Cravings", systemImage: "heart.text.square")
                    }
                    if currentSnapshot.showsBathroomReport {
                        NavigationLink {
                            BathroomReportView(snapshot: currentSnapshot)
                        } label: {
                            Label("Bathroom", systemImage: "toilet")
                        }
                    }
                }
            }
            .navigationTitle("Reports")
            .toolbar {
                if showsCloseButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
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
    var valueColor: Color? = nil

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(valueColor ?? .primary)
        }
        .font(.subheadline)
    }
}

/// The three marquee-weight reports (Eating report, Snapshot, Calendar heatmap) get a bigger,
/// scannable tile instead of blending into the flat list of section reports below them.
struct ReportMarqueeCard<Destination: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    @ViewBuilder var destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            Card {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Image(systemName: systemImage)
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(width: 168, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
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
                    .chartPaddedYScale(
                        values: snapshot.proteinSeries.map(\.value) + snapshot.proteinGoalSeries.map(\.value),
                        pad: ChartValueScale.proteinPadKcal,
                        floorAtZero: true
                    )
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
                    .chartPaddedYScale(
                        values: snapshot.hydrationSeries.map(\.value),
                        goal: snapshot.hydrationTarget,
                        pad: ChartValueScale.waterPadOz,
                        floorAtZero: true
                    )
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
    @AppStorage("reportChartShowGoal") private var showGoal = true
    @AppStorage("reportChartShowStart") private var showStart = true
    @AppStorage("reportChartShowTrend") private var showTrend = true

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
                if let start = snapshot.weightSeries.first {
                    ReportMetricRow(title: "Start weight", value: String(format: "%.1f %@", start.value, unit))
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

                if !snapshot.weightSeries.isEmpty || snapshot.bmiSeries.count >= 2 {
                    ReportChartGuideToggles(
                        showGoal: $showGoal,
                        showStart: $showStart,
                        showTrend: $showTrend,
                        hasGoal: snapshot.goalWeightDisplay != nil
                    )
                }

                if !snapshot.weightSeries.isEmpty {
                    Text("Weight")
                        .font(.headline)
                    Chart {
                        ReportSeriesGuides.marks(
                            series: snapshot.weightSeries,
                            yLabel: "Weight",
                            goal: snapshot.goalWeightDisplay,
                            showGoal: showGoal,
                            showStart: showStart,
                            showTrend: showTrend
                        )
                    }
                    .frame(height: 200)
                    .chartYAxisLabel(unit)
                    .chartLegend(.hidden)
                    .chartPaddedYScale(
                        values: ReportSeriesGuides.domainValues(
                            series: snapshot.weightSeries,
                            showTrend: showTrend
                        ),
                        goal: snapshot.goalWeightDisplay,
                        pad: ChartValueScale.weightPad(usesMetric: snapshot.settings.usesMetricWeight)
                    )
                }

                if snapshot.bmiSeries.count >= 2 {
                    Text("BMI")
                        .font(.headline)
                    Chart {
                        ReportSeriesGuides.marks(
                            series: snapshot.bmiSeries,
                            yLabel: "BMI",
                            goal: snapshot.goalBMI,
                            showGoal: showGoal,
                            showStart: showStart,
                            showTrend: showTrend
                        )
                    }
                    .frame(height: 200)
                    .chartLegend(.hidden)
                    .chartPaddedYScale(
                        values: ReportSeriesGuides.domainValues(
                            series: snapshot.bmiSeries,
                            showTrend: showTrend
                        ),
                        goal: snapshot.goalBMI,
                        pad: ChartValueScale.bmiPad(heightInches: snapshot.settings.heightInches)
                    )
                }

                if snapshot.weightSeries.isEmpty {
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
                    .chartPaddedYScale(
                        values: snapshot.cigaretteSeries.map(\.value),
                        goal: snapshot.settings.effectiveDailyCigaretteLimit.map(Double.init),
                        pad: ChartValueScale.countPad,
                        floorAtZero: true
                    )
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
                    .chartPaddedYScale(
                        values: snapshot.drinkSeries.map(\.value),
                        goal: snapshot.settings.effectiveDailyDrinkLimit.map(Double.init),
                        pad: ChartValueScale.countPad,
                        floorAtZero: true
                    )
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

struct BathroomReportView: View {
    let snapshot: ReportSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ReportMetricRow(title: "Urine", value: "\(snapshot.totalUrine)")
                ReportMetricRow(title: "Stool", value: "\(snapshot.totalStool)")
                ReportMetricRow(
                    title: "Days logged",
                    value: "\(snapshot.daysWithBathroomLog)/\(snapshot.logs.count)"
                )

                if snapshot.totalUrine > 0 {
                    Text("Urine / day")
                        .font(.headline)
                    Chart(snapshot.urineSeries) { point in
                        BarMark(
                            x: .value("Day", point.date),
                            y: .value("Count", point.value)
                        )
                        .foregroundStyle(Color.accentColor)
                    }
                    .frame(height: 180)
                }

                if snapshot.totalStool > 0 {
                    Text("Stool / day")
                        .font(.headline)
                    Chart(snapshot.stoolSeries) { point in
                        BarMark(
                            x: .value("Day", point.date),
                            y: .value("Count", point.value)
                        )
                        .foregroundStyle(Color.orange)
                    }
                    .frame(height: 180)
                }

                if snapshot.totalUrine == 0 && snapshot.totalStool == 0 {
                    EmptyReportHint()
                }
            }
            .padding()
        }
        .navigationTitle("Bathroom")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct BodyCompositionReportView: View {
    let snapshot: ReportSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                let unit = snapshot.settings.usesMetricWeight ? "kg" : "lb"
                ReportMetricRow(title: "Readings", value: "\(snapshot.bodyCompositions.count)")
                if let fat = snapshot.latestFatPercent {
                    ReportMetricRow(title: "Latest fat %", value: String(format: "%.1f%%", fat))
                }
                if let bmi = snapshot.latestBodyCompBMI {
                    ReportMetricRow(
                        title: "Latest BMI",
                        value: String(format: "%.1f (%@)", bmi, BMICalculator.category(for: bmi))
                    )
                }
                if let weight = snapshot.latestBodyCompWeightDisplay {
                    ReportMetricRow(title: "Latest weight", value: String(format: "%.1f %@", weight, unit))
                }
                if let fatMass = snapshot.latestFatMassDisplay {
                    ReportMetricRow(title: "Latest fat mass", value: String(format: "%.1f %@", fatMass, unit))
                }

                if !snapshot.fatPercentSeries.isEmpty {
                    Text("Body fat %")
                        .font(.headline)
                    Chart(snapshot.fatPercentSeries) { point in
                        LineMark(
                            x: .value("Day", point.date),
                            y: .value("Fat %", point.value)
                        )
                        PointMark(
                            x: .value("Day", point.date),
                            y: .value("Fat %", point.value)
                        )
                    }
                    .frame(height: 200)
                    .chartYAxisLabel("%")
                    .chartPaddedYScale(
                        values: snapshot.fatPercentSeries.map(\.value),
                        pad: ChartValueScale.fatPercentPad
                    )
                }

                if !snapshot.bodyCompWeightSeries.isEmpty {
                    Text("Weight")
                        .font(.headline)
                    Chart(snapshot.bodyCompWeightSeries) { point in
                        LineMark(
                            x: .value("Day", point.date),
                            y: .value("Weight", point.value)
                        )
                        PointMark(
                            x: .value("Day", point.date),
                            y: .value("Weight", point.value)
                        )
                    }
                    .frame(height: 200)
                    .chartYAxisLabel(unit)
                    .chartPaddedYScale(
                        values: snapshot.bodyCompWeightSeries.map(\.value),
                        goal: snapshot.goalWeightDisplay,
                        pad: ChartValueScale.weightPad(usesMetric: snapshot.settings.usesMetricWeight)
                    )
                }

                if snapshot.bodyCompositions.isEmpty {
                    EmptyReportHint()
                }
            }
            .padding()
        }
        .navigationTitle("Body composition")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TapeMeasurementsReportView: View {
    let snapshot: ReportSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                let unit = snapshot.settings.usesMetricWeight ? "cm" : "in"
                ReportMetricRow(title: "Sessions", value: "\(snapshot.measurements.count)")
                if let waist = snapshot.latestWaistDisplay {
                    ReportMetricRow(title: "Latest waist", value: String(format: "%.1f %@", waist, unit))
                }
                if let summary = snapshot.latestMeasurementSummary {
                    ReportMetricRow(title: "Latest", value: summary)
                }

                if !snapshot.waistSeries.isEmpty {
                    Text("Waist")
                        .font(.headline)
                    Chart(snapshot.waistSeries) { point in
                        LineMark(
                            x: .value("Day", point.date),
                            y: .value("Waist", point.value)
                        )
                        PointMark(
                            x: .value("Day", point.date),
                            y: .value("Waist", point.value)
                        )
                    }
                    .frame(height: 200)
                    .chartYAxisLabel(unit)
                    .chartPaddedYScale(
                        values: snapshot.waistSeries.map(\.value),
                        pad: ChartValueScale.lengthPad(usesMetric: snapshot.settings.usesMetricWeight)
                    )
                }

                if snapshot.neckSeries.count >= 2 {
                    Text("Neck")
                        .font(.headline)
                    Chart(snapshot.neckSeries) { point in
                        LineMark(
                            x: .value("Day", point.date),
                            y: .value("Neck", point.value)
                        )
                        PointMark(
                            x: .value("Day", point.date),
                            y: .value("Neck", point.value)
                        )
                    }
                    .frame(height: 200)
                    .chartYAxisLabel(unit)
                    .chartPaddedYScale(
                        values: snapshot.neckSeries.map(\.value),
                        pad: ChartValueScale.lengthPad(usesMetric: snapshot.settings.usesMetricWeight)
                    )
                }

                if snapshot.measurements.isEmpty {
                    EmptyReportHint()
                }
            }
            .padding()
        }
        .navigationTitle("Tape measurements")
        .navigationBarTitleDisplayMode(.inline)
    }
}
