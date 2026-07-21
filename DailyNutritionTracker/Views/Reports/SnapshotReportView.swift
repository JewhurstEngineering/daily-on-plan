import SwiftUI
import Charts

struct SnapshotReportView: View {
    let snapshot: ReportSnapshot
    @State private var shareURL: URL?
    @State private var isRendering = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if snapshot.logs.isEmpty {
                    EmptyReportHint()
                } else {
                    header
                    averageDayCard
                    weeklySection
                    callouts
                }
            }
            .padding()
        }
        .navigationTitle("Snapshot")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Today card") { share(.today) }
                    Button("Streak card") { share(.streak) }
                    Button("Heatmap card") { share(.heatmap) }
                } label: {
                    if isRendering {
                        ProgressView()
                    } else {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
                .disabled(isRendering || snapshot.logs.isEmpty)
            }
        }
        .sheet(item: Binding(
            get: { shareURL.map { SnapshotShareItem(url: $0) } },
            set: { shareURL = $0?.url }
        )) { item in
            ShareSheet(items: [item.url])
        }
    }

    private enum ShareKind { case today, streak, heatmap }

    @MainActor
    private func share(_ kind: ShareKind) {
        isRendering = true
        Task { @MainActor in
            defer { isRendering = false }
            switch kind {
            case .today:
                shareURL = ShareCardBuilder.todayURL(from: snapshot)
            case .streak:
                shareURL = ShareCardBuilder.streakURL(from: snapshot)
            case .heatmap:
                let metric = snapshot.availableHeatmapMetrics.first ?? .followedPlan
                let month = DateHelpers.startOfDay(snapshot.end)
                let days = snapshot.heatmapDays(for: metric).filter {
                    Calendar.current.isDate($0.date, equalTo: month, toGranularity: .month)
                }
                let card = HeatmapShareCard(
                    month: month,
                    metric: metric,
                    days: days,
                    brand: AppIdentity.displayName
                )
                shareURL = ShareCardRenderer.writePNG(of: card, size: CGSize(width: 360, height: 420))
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(snapshot.logs.count) days logged")
                .font(.title3.bold())
            Text("\(snapshot.start.formatted(.dateTime.month().day().year())) – \(snapshot.end.formatted(.dateTime.month().day().year()))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var averageDayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Average day", systemImage: "sun.max")
                .font(.headline)

            metricGrid

            if !snapshot.proteinSeries.isEmpty {
                Text("Protein vs goal")
                    .font(.subheadline.weight(.semibold))
                Chart {
                    ForEach(snapshot.proteinSeries) { point in
                        LineMark(
                            x: .value("Day", point.date),
                            y: .value("kcal", point.value),
                            series: .value("Series", "Actual")
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
                .frame(height: 160)
            }

            if !snapshot.offPlanReasonCounts.isEmpty {
                Text("Off-plan reasons")
                    .font(.subheadline.weight(.semibold))
                Text("Tagged on days you didn’t follow the plan. A day can count toward more than one reason.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                ForEach(snapshot.offPlanReasonCounts.prefix(8)) { item in
                    ReportMetricRow(title: item.name, value: "\(item.count)×")
                }
            }

            if !snapshot.hydrationSeries.isEmpty {
                Text("Water intake")
                    .font(.subheadline.weight(.semibold))
                Chart {
                    ForEach(snapshot.hydrationSeries) { point in
                        LineMark(
                            x: .value("Day", point.date),
                            y: .value("oz", point.value)
                        )
                        .foregroundStyle(Color.accentColor)
                    }
                    RuleMark(y: .value("Target", snapshot.hydrationTarget))
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(dash: [4, 3]))
                }
                .frame(height: 140)
            }

            if snapshot.weightSeries.count > 1 {
                Text("Weight")
                    .font(.subheadline.weight(.semibold))
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
                    }
                }
                .frame(height: 140)
                .chartYAxisLabel(snapshot.settings.usesMetricWeight ? "kg" : "lb")
            }

            if snapshot.showsSmokingReport, !snapshot.cigaretteSeries.isEmpty {
                Text("Cigarettes")
                    .font(.subheadline.weight(.semibold))
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
                .frame(height: 140)
            }

            if snapshot.showsDrinkingReport, !snapshot.drinkSeries.isEmpty {
                Text("Drinks")
                    .font(.subheadline.weight(.semibold))
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
                .frame(height: 140)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var metricGrid: some View {
        let unit = snapshot.settings.usesMetricWeight ? "kg" : "lb"
        return VStack(spacing: 10) {
            ReportMetricRow(
                title: "Avg protein",
                value: String(format: "%.0f / %.0f kcal", snapshot.avgProteinCalories, snapshot.avgProteinGoal)
            )
            ReportMetricRow(
                title: "Days ≤ protein goal",
                value: "\(snapshot.daysOnProteinGoal)/\(snapshot.logs.count)"
            )
            ReportMetricRow(
                title: "Avg water",
                value: String(format: "%.0f oz (%.0f%% hit target)", snapshot.avgWaterOz, snapshot.hydrationHitRate)
            )
            ReportMetricRow(
                title: "Avg feelings / day",
                value: String(format: "%.1f%@", snapshot.avgFeelingsPerDay, snapshot.feelingCounts.first.map { " · top: \($0.name)" } ?? "")
            )
            ReportMetricRow(
                title: "Avg veggies logged",
                value: String(format: "%.1f / day", snapshot.avgVeggiesPerDay)
            )
            ReportMetricRow(
                title: "Avg workout minutes",
                value: String(format: "%.0f / day", snapshot.avgWorkoutMinutesPerDay)
            )
            ReportMetricRow(
                title: "Supplement adherence",
                value: String(format: "%.0f%%", snapshot.overallSupplementAdherencePercent)
            )
            ReportMetricRow(
                title: "Followed plan",
                value: String(format: "%.0f%% of days", snapshot.planFollowRate)
            )
            if snapshot.offPlanDays > 0 {
                ReportMetricRow(
                    title: "Off-plan days",
                    value: "\(snapshot.offPlanDays)/\(snapshot.logs.count)"
                )
            }
            ReportMetricRow(
                title: "Ketosis",
                value: String(format: "%.0f%% of days", snapshot.ketosisRate)
            )
            if let delta = snapshot.weightDelta {
                ReportMetricRow(
                    title: "Weight change",
                    value: String(format: "%@%.1f %@", delta >= 0 ? "+" : "", delta, unit)
                )
            }
            if let goal = snapshot.goalWeightDisplay {
                ReportMetricRow(
                    title: "Goal weight",
                    value: String(format: "%.1f %@", goal, unit)
                )
            }
            if let toGo = snapshot.weightToGoDisplay {
                ReportMetricRow(title: "Vs goal", value: weightToGoLabel(toGo, unit: unit))
            }
            if snapshot.showsSmokingReport {
                ReportMetricRow(
                    title: "Avg cigarettes / day",
                    value: String(format: "%.1f (%@)", snapshot.avgCigarettesPerDay, CigarettePackMath.packsLabel(cigarettes: Int(snapshot.avgCigarettesPerDay.rounded())))
                )
                ReportMetricRow(
                    title: "Smoke-free days",
                    value: "\(snapshot.smokeFreeDaysInRange)/\(snapshot.logs.count)"
                )
            }
            if snapshot.showsDrinkingReport {
                ReportMetricRow(
                    title: "Avg drinks / day",
                    value: String(format: "%.1f", snapshot.avgDrinksPerDay)
                )
                ReportMetricRow(
                    title: "Alcohol-free days",
                    value: "\(snapshot.alcoholFreeDaysInRange)/\(snapshot.logs.count)"
                )
            }
            if let bmi = snapshot.latestBMI {
                ReportMetricRow(
                    title: "Latest BMI",
                    value: String(format: "%.1f (%@)", bmi, BMICalculator.category(for: bmi))
                )
            }
        }
    }

    private func weightToGoLabel(_ toGo: Double, unit: String) -> String {
        if abs(toGo) < 0.05 { return "At goal" }
        if toGo > 0 { return String(format: "%.1f %@ to go", toGo, unit) }
        return String(format: "%.1f %@ under goal", abs(toGo), unit)
    }

    private var weeklySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Weekly rollup", systemImage: "calendar")
                .font(.headline)

            if snapshot.weeklyRollups.isEmpty {
                Text("Not enough days for a weekly view.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(snapshot.weeklyRollups.reversed()) { week in
                    weekCard(week)
                }
            }
        }
    }

    private func weekCard(_ week: ReportSnapshot.WeekRollup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(week.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(week.loggedDays) days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                miniStat(title: "Protein", value: String(format: "%.0f", week.avgProtein))
                miniStat(title: "Water", value: String(format: "%.0f oz", week.avgWater))
                miniStat(title: "Feelings", value: "\(week.totalFeelings)")
                miniStat(title: "Workout", value: "\(week.totalWorkoutMinutes)m")
            }

            ReportMetricRow(title: "On protein goal", value: "\(week.daysOnProteinGoal)/\(week.loggedDays)")
            ReportMetricRow(title: "Hit water target", value: "\(week.daysAtWaterTarget)/\(week.loggedDays)")
            ReportMetricRow(title: "Followed plan", value: "\(week.planFollowDays)/\(week.loggedDays)")

            if week.proteinSpark.count > 1 {
                Chart(week.proteinSpark) { point in
                    AreaMark(
                        x: .value("Day", point.date),
                        y: .value("kcal", point.value)
                    )
                    .foregroundStyle(Color.accentColor.opacity(0.25))
                    LineMark(
                        x: .value("Day", point.date),
                        y: .value("kcal", point.value)
                    )
                    .foregroundStyle(Color.accentColor)
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 44)
                .accessibilityLabel("Protein sparkline for \(week.title)")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func miniStat(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption.weight(.semibold).monospacedDigit())
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var callouts: some View {
        let weeks = snapshot.weeklyRollups
        if weeks.count >= 1 {
            VStack(alignment: .leading, spacing: 12) {
                Label("Highlights", systemImage: "sparkles")
                    .font(.headline)

                if let best = snapshot.bestWeek {
                    calloutCard(
                        title: "Best week",
                        detail: "\(best.title) · \(best.daysOnProteinGoal) protein-on-goal days, \(best.daysAtWaterTarget) water-target days"
                    )
                }
                if let tough = snapshot.toughestWeek, weeks.count > 1 {
                    calloutCard(
                        title: "Toughest week",
                        detail: "\(tough.title) · \(tough.totalFeelings) feeling/craving events"
                    )
                }
                if let topFeeling = snapshot.feelingCounts.first {
                    calloutCard(
                        title: "Most common feeling",
                        detail: "\(topFeeling.name) (\(topFeeling.count)× in range)"
                    )
                }
                if let topOffPlan = snapshot.offPlanReasonCounts.first {
                    calloutCard(
                        title: "Most common off-plan reason",
                        detail: "\(topOffPlan.name) (\(topOffPlan.count)× in range)"
                    )
                }
            }
        }
    }

    private func calloutCard(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct SnapshotShareItem: Identifiable {
    var id: String { url.absoluteString }
    let url: URL
}
