import SwiftUI
import SwiftData
import Charts

/// Reports, rebuilt as a scrolling chart feed: one range control at the top scopes every
/// card below it, and each card leads with the single number that answers its question.
///
/// Replaces the old list of navigation links into dense text tables. Those tables still
/// exist — they are reachable from "All reports" at the bottom — but they are no longer
/// the only way to see a trend. See the redesign canvas, page "Reports".
struct TrendsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appTheme) private var appTheme

    @State private var range: ReportRange = .days30
    @State private var endDate = Date()
    @State private var customStart = Calendar.current.date(byAdding: .day, value: -13, to: Date()) ?? Date()

    private var snapshot: ReportSnapshot {
        ReportAggregator.snapshot(
            range: range,
            endDate: endDate,
            customStart: customStart,
            in: modelContext
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    rangeControl

                    let snap = snapshot

                    if snap.logs.isEmpty && snap.weights.isEmpty {
                        emptyState
                    } else {
                        WeightTrendCard(snapshot: snap)
                        ProteinTrendCard(snapshot: snap)
                        HydrationTrendCard(snapshot: snap)
                        PlanTrendCard(snapshot: snap)
                        moreCard(snapshot: snap)
                    }
                }
                .padding()
            }
            .background(Color.onPlanGroupedBackground)
            .navigationTitle("Trends")
            .onPlanInlineNav()
        }
    }

    // MARK: - One filter row, scoping every card below

    private var rangeControl: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Picker("Range", selection: $range) {
                ForEach(ReportRange.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            if range == .custom {
                DatePicker("From", selection: $customStart, in: ...endDate, displayedComponents: .date)
                    .font(.subheadline)
                DatePicker("To", selection: $endDate, displayedComponents: .date)
                    .font(.subheadline)
            }

            Text(rangeCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var rangeCaption: String {
        let snap = snapshot
        let start = snap.start.formatted(.dateTime.month(.abbreviated).day())
        let end = snap.end.formatted(.dateTime.month(.abbreviated).day())
        return "\(start) – \(end) · \(snap.logs.count) of \(snap.dayCount) days logged"
    }

    private var emptyState: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("Nothing logged in this range")
                    .font(.headline)
                Text("Log a weight, a meal or some water and the charts fill in from your own days — nothing here is sample data.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func moreCard(snapshot: ReportSnapshot) -> some View {
        Card {
            VStack(spacing: 0) {
                NavigationLink {
                    EatingReportView(snapshot: snapshot)
                } label: {
                    TrendLinkRow(title: "What I've been eating", systemImage: "list.bullet.rectangle")
                }
                .buttonStyle(.plain)

                Divider()

                NavigationLink {
                    CalendarHeatmapView(snapshot: snapshot)
                } label: {
                    TrendLinkRow(title: "Calendar heatmap", systemImage: "calendar")
                }
                .buttonStyle(.plain)

                Divider()

                NavigationLink {
                    ReportsView(showsCloseButton: false)
                } label: {
                    TrendLinkRow(title: "All reports", systemImage: "square.grid.2x2", detail: "Body, habits, wellbeing")
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct TrendLinkRow: View {
    let title: String
    let systemImage: String
    var detail: String? = nil

    var body: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
                .frame(width: 22)
            Text(title)
                .foregroundStyle(.primary)
            Spacer(minLength: Spacing.s)
            if let detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

// MARK: - Card shell

/// Title, the one number that answers the question, then the plot. Every card carries a
/// table toggle so no value is reachable only by reading a colour off a chart.
struct TrendCard<Chart: View, Table: View>: View {
    let title: String
    let heroValue: String
    let heroCaption: String
    var trailing: String?
    var trailingTint: Color?
    @ViewBuilder var chart: Chart
    @ViewBuilder var table: Table

    @State private var showsTable = false

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.m) {
                HStack(spacing: Spacing.s) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: Spacing.s)
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showsTable.toggle() }
                    } label: {
                        Image(systemName: showsTable ? "chart.xyaxis.line" : "tablecells")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 36, minHeight: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(showsTable ? "Show chart" : "Show values as a table")
                }

                HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                    Text(heroValue)
                        .font(.system(size: 28, weight: .bold))
                    Text(heroCaption)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: Spacing.xs)
                    if let trailing {
                        Text(trailing)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(trailingTint ?? .secondary)
                    }
                }

                if showsTable {
                    table
                } else {
                    chart
                }
            }
        }
    }
}

/// Compact value list used by every card's table view.
struct TrendTable: View {
    let rows: [(label: String, value: String)]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.prefix(14).enumerated()), id: \.offset) { index, row in
                if index > 0 { Divider() }
                HStack {
                    Text(row.label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(row.value)
                        .font(.subheadline.monospacedDigit())
                }
                .frame(minHeight: 30)
            }
            if rows.count > 14 {
                Text("Showing the most recent 14 of \(rows.count) days")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Spacing.xs)
            }
        }
    }
}

// MARK: - Weight

struct WeightTrendCard: View {
    let snapshot: ReportSnapshot
    @Environment(\.appTheme) private var appTheme

    private var unit: String { snapshot.settings.usesMetricWeight ? "kg" : "lb" }
    private var series: [DailyMetricPoint] { snapshot.weightSeries }

    private var latest: Double? { series.last?.value }

    /// Pad a nearly-flat series so ordinary noise doesn't fill the plot.
    private var domain: ClosedRange<Double> {
        let values = series.map(\.value)
        guard let low = values.min(), let high = values.max() else { return 0...1 }
        let span = max(high - low, snapshot.settings.usesMetricWeight ? 3 : 6)
        let pad = (span - (high - low)) / 2 + span * 0.08
        return (low - pad)...(high + pad)
    }

    var body: some View {
        TrendCard(
            title: "Weight & BMI",
            heroValue: latest.map { String(format: "%.1f", $0) } ?? "—",
            heroCaption: unit,
            trailing: snapshot.weightDelta.map { String(format: "%@%.1f %@ in range", $0 < 0 ? "−" : "+", abs($0), unit) },
            trailingTint: (snapshot.weightDelta ?? 0) < 0 ? appTheme.ok : .secondary
        ) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                if series.count > 1 {
                    Chart {
                        ForEach(series) { point in
                            AreaMark(
                                x: .value("Day", point.date),
                                y: .value(unit, point.value)
                            )
                            .foregroundStyle(
                                .linearGradient(
                                    colors: [appTheme.tint.opacity(0.26), appTheme.tint.opacity(0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            LineMark(
                                x: .value("Day", point.date),
                                y: .value(unit, point.value)
                            )
                            .foregroundStyle(appTheme.tint)
                            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                            .interpolationMethod(.catmullRom)
                        }
                        if let last = series.last {
                            PointMark(
                                x: .value("Day", last.date),
                                y: .value(unit, last.value)
                            )
                            .foregroundStyle(appTheme.tint)
                            .symbolSize(70)
                        }
                    }
                    .chartYScale(domain: domain)
                    .trendAxes(yPosition: .leading)
                    .frame(height: 150)
                    .clipped()
                } else {
                    ChartPlaceholder(text: "Log at least two weigh-ins to see a trend.")
                }

                goalStrip
            }
        } table: {
            TrendTable(rows: series.reversed().map {
                ($0.label, String(format: "%.1f %@", $0.value, unit))
            })
        }
    }

    @ViewBuilder
    private var goalStrip: some View {
        if let goal = snapshot.settings.goalWeightLbs, let latestLbs = snapshot.weights.last?.weightLbs {
            let display = snapshot.settings.usesMetricWeight ? 0.453592 : 1.0
            let remaining = max(0, latestLbs - goal)
            Divider()
            HStack(spacing: 0) {
                trendStat(String(format: "%.0f", goal * display), "Goal \(unit)")
                trendStat(String(format: "%.0f", remaining * display), "To go")
                if let bmi = snapshot.latestBMI {
                    trendStat(String(format: "%.1f", bmi), "BMI")
                }
                trendStat("\(snapshot.weights.count)", "Entries")
            }
        }
    }

    private func trendStat(_ value: String, _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Protein

struct ProteinTrendCard: View {
    let snapshot: ReportSnapshot
    @Environment(\.appTheme) private var appTheme

    private var series: [DailyMetricPoint] { snapshot.proteinSeries }
    private var goal: Double { snapshot.avgProteinGoal }

    var body: some View {
        TrendCard(
            title: "Protein vs goal",
            heroValue: "\(snapshot.daysOnProteinGoal)",
            heroCaption: "of \(snapshot.logs.count) days at or under goal",
            trailing: "avg \(Int(snapshot.avgProteinCalories.rounded()))"
        ) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                if series.isEmpty {
                    ChartPlaceholder(text: "No meals logged in this range.")
                } else {
                    Chart {
                        ForEach(series) { point in
                            BarMark(
                                x: .value("Day", point.date, unit: .day),
                                y: .value("kcal", point.value)
                            )
                            // The goal is a ceiling in this app, so exceeding it is a
                            // warning, not a win.
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
                    .frame(height: 130)

                    ChartLegend(items: [
                        (appTheme.protein, "At or under goal  \(snapshot.daysOnProteinGoal)"),
                        (appTheme.warn, "Over  \(snapshot.daysOverProteinGoal)")
                    ])
                }
            }
        } table: {
            TrendTable(rows: series.reversed().map {
                ($0.label, "\(Int($0.value)) kcal")
            })
        }
    }
}

// MARK: - Hydration

struct HydrationTrendCard: View {
    let snapshot: ReportSnapshot
    @Environment(\.appTheme) private var appTheme

    private var series: [DailyMetricPoint] { snapshot.hydrationSeries }
    private var target: Double { snapshot.hydrationTarget }
    private var daysHit: Int { series.filter { $0.value >= target }.count }

    var body: some View {
        TrendCard(
            title: "Hydration",
            heroValue: "\(Int(snapshot.avgWaterOz.rounded()))",
            heroCaption: "oz average per day",
            trailing: "\(daysHit) at target"
        ) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                if series.isEmpty {
                    ChartPlaceholder(text: "No drinks logged in this range.")
                } else {
                    Chart {
                        ForEach(series) { point in
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
                                Text("Target \(Int(target.rounded())) oz")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(appTheme.water)
                            }
                    }
                    .trendAxes()
                    .frame(height: 130)

                    ChartLegend(items: [
                        (appTheme.water, "Hit target  \(daysHit)"),
                        (appTheme.water.opacity(0.32), "Short  \(series.count - daysHit)")
                    ])
                }
            }
        } table: {
            TrendTable(rows: series.reversed().map {
                ($0.label, "\(Int($0.value)) oz")
            })
        }
    }
}

// MARK: - Plan

struct PlanTrendCard: View {
    let snapshot: ReportSnapshot
    @Environment(\.appTheme) private var appTheme

    private var days: [HeatmapDay] { snapshot.heatmapDays(for: .followedPlan) }

    var body: some View {
        TrendCard(
            title: "On plan",
            heroValue: "\(Int(snapshot.planFollowRate.rounded()))%",
            heroCaption: "of logged days followed plan",
            trailing: snapshot.currentPlanFollowStreak > 0 ? "\(snapshot.currentPlanFollowStreak)-day streak" : nil,
            trailingTint: appTheme.ok
        ) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 5) {
                    ForEach(days) { day in
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(color(for: day))
                            .aspectRatio(1, contentMode: .fit)
                            .accessibilityLabel(accessibility(for: day))
                    }
                }

                ChartLegend(items: [
                    (appTheme.ok, "On plan"),
                    (appTheme.warn.opacity(0.55), "Off plan"),
                    (Color.onPlanTertiaryFill, "Not logged")
                ])
            }
        } table: {
            TrendTable(rows: days.reversed().map {
                (
                    $0.date.formatted(.dateTime.month(.abbreviated).day()),
                    $0.hit.map { $0 ? "On plan" : "Off plan" } ?? "—"
                )
            })
        }
    }

    private func color(for day: HeatmapDay) -> Color {
        guard let hit = day.hit else { return Color.onPlanTertiaryFill }
        return hit ? appTheme.ok : appTheme.warn.opacity(0.55)
    }

    private func accessibility(for day: HeatmapDay) -> String {
        let date = day.date.formatted(.dateTime.month(.abbreviated).day())
        guard let hit = day.hit else { return "\(date), not logged" }
        return "\(date), \(hit ? "on plan" : "off plan")"
    }
}

// MARK: - Shared chart chrome

struct ChartLegend: View {
    let items: [(Color, String)]

    var body: some View {
        HStack(spacing: Spacing.l) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(item.0)
                        .frame(width: 9, height: 9)
                    Text(item.1)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct ChartPlaceholder: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
    }
}


extension View {
    /// Solid hairline gridlines and recessive labels. Swift Charts dashes gridlines by
    /// default, which reads as a threshold or a projection when it is only a grid.
    func trendAxes(yPosition: AxisMarkPosition = .trailing) -> some View {
        chartXAxis {
            AxisMarks { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                AxisValueLabel()
            }
        }
        .chartYAxis {
            AxisMarks(position: yPosition) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                AxisValueLabel()
            }
        }
    }
}
