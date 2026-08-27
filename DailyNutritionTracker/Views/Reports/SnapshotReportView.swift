import SwiftUI
import Charts

struct SnapshotReportView: View {
    let snapshot: ReportSnapshot
    @State private var shareURL: URL?
    @State private var isRendering = false
    @AppStorage("reportChartShowGoal") private var showGoal = true
    @AppStorage("reportChartShowStart") private var showStart = true
    @AppStorage("reportChartShowTrend") private var showTrend = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                if snapshot.logs.isEmpty {
                    EmptyReportHint()
                } else {
                    header
                    averageDayCard
                    // The Trends feed already owns these charts — reuse them rather than
                    // maintaining a second, differently-styled copy here.
                    WeightTrendCard(snapshot: snapshot)
                    ProteinTrendCard(snapshot: snapshot)
                    HydrationTrendCard(snapshot: snapshot)
                    PlanTrendCard(snapshot: snapshot)
                    offPlanCard
                    weeklySection
                    callouts
                }
            }
            .padding()
        }
        .background(Color.onPlanGroupedBackground)
        .navigationTitle("Snapshot")
        .onPlanInlineNav()
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
        Card {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Label("Average day", systemImage: "sun.max")
                    .font(.subheadline.weight(.semibold))
                metricGrid
            }
        }
    }

    @ViewBuilder
    private var offPlanCard: some View {
        if !snapshot.offPlanReasonCounts.isEmpty {
            Card {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("Off-plan reasons")
                        .font(.subheadline.weight(.semibold))
                    Text("Tagged on days you didn't follow the plan. A day can count toward more than one reason.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(snapshot.offPlanReasonCounts.prefix(8)) { item in
                        Divider()
                        HStack {
                            Text(item.name)
                                .font(.subheadline)
                            Spacer()
                            Text("\(item.count)×")
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                        }
                        .frame(minHeight: 30)
                    }
                }
            }
        }
    }

    /// Two-up tiles: the same figures as before, but scannable instead of a column of
    /// twenty label/value rows.
    private var metricGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: Spacing.s), GridItem(.flexible(), spacing: Spacing.s)],
            spacing: Spacing.s
        ) {
            ForEach(Array(averageDayStats.enumerated()), id: \.offset) { _, stat in
                VStack(alignment: .leading, spacing: 2) {
                    Text(stat.value)
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(stat.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .topLeading)
                .padding(Spacing.s)
                .background(Color.onPlanTertiaryFill, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            }
        }
    }

    private var averageDayStats: [(title: String, value: String)] {
        let unit = snapshot.settings.usesMetricWeight ? "kg" : "lb"
        var stats: [(String, String)] = [
            ("Avg protein", String(format: "%.0f kcal", snapshot.avgProteinCalories)),
            ("Days ≤ protein goal", "\(snapshot.daysOnProteinGoal)/\(snapshot.logs.count)"),
            ("Avg water", String(format: "%.0f oz", snapshot.avgWaterOz)),
            ("Hit water target", String(format: "%.0f%%", snapshot.hydrationHitRate)),
            ("Followed plan", String(format: "%.0f%%", snapshot.planFollowRate)),
            ("Ketosis", String(format: "%.0f%%", snapshot.ketosisRate)),
            ("Avg veggies / day", String(format: "%.1f", snapshot.avgVeggiesPerDay)),
            ("Avg workout min", String(format: "%.0f", snapshot.avgWorkoutMinutesPerDay)),
            ("Avg feelings / day", String(format: "%.1f", snapshot.avgFeelingsPerDay)),
            ("Supplement adherence", String(format: "%.0f%%", snapshot.overallSupplementAdherencePercent))
        ]
        if snapshot.offPlanDays > 0 {
            stats.append(("Off-plan days", "\(snapshot.offPlanDays)/\(snapshot.logs.count)"))
        }
        if let delta = snapshot.weightDelta {
            stats.append(("Weight change", String(format: "%@%.1f %@", delta >= 0 ? "+" : "−", abs(delta), unit)))
        }
        if let goal = snapshot.goalWeightDisplay {
            stats.append(("Goal weight", String(format: "%.0f %@", goal, unit)))
        }
        if let toGo = snapshot.weightToGoDisplay {
            stats.append(("Vs goal", weightToGoLabel(toGo, unit: unit)))
        }
        if snapshot.showsSmokingReport {
            stats.append(("Avg cigs / day", String(format: "%.1f", snapshot.avgCigarettesPerDay)))
            stats.append(("Smoke-free days", "\(snapshot.smokeFreeDaysInRange)/\(snapshot.logs.count)"))
        }
        if snapshot.showsDrinkingReport {
            stats.append(("Avg drinks / day", String(format: "%.1f", snapshot.avgDrinksPerDay)))
            stats.append(("Alcohol-free days", "\(snapshot.alcoholFreeDaysInRange)/\(snapshot.logs.count)"))
        }
        return stats
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
        Card {
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
        }
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
