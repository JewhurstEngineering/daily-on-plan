import SwiftUI

/// Colors intake totals by absolute % distance from a target.
/// ≤10% green · 11–15% yellow · 16–20% orange · ≥21% red.
private enum IntakeTargetColor {
    /// Aim for an exact target (protein kcal, water oz). Over or under both count.
    static func towardTarget(current: Int, target: Int) -> Color {
        guard target > 0 else { return .secondary }
        let deviationPercent = abs(Double(current - target) / Double(target)) * 100
        return band(deviationPercent)
    }

    /// Floor goal (e.g. veggies): meeting or exceeding is green; only shortfall is penalized.
    static func meetingMinimum(current: Int, minimum: Int) -> Color {
        guard minimum > 0 else { return .secondary }
        if current >= minimum { return .green }
        let shortfallPercent = Double(minimum - current) / Double(minimum) * 100
        return band(shortfallPercent)
    }

    /// Ceiling (e.g. misc max): at or under is green; only excess is penalized.
    static func underMaximum(current: Int, maximum: Int) -> Color {
        guard maximum > 0 else { return .secondary }
        if current <= maximum { return .green }
        let excessPercent = Double(current - maximum) / Double(maximum) * 100
        return band(excessPercent)
    }

    private static func band(_ deviationPercent: Double) -> Color {
        switch deviationPercent {
        case ...10: return .green
        case ...15: return .yellow
        case ...20: return .orange
        default: return .red
        }
    }
}

/// Soft plan defaults used only in the eating report (not stored settings).
private enum EatingReportTargets {
    static let vegetablesPerDay = 3
}

private enum EatingReportMode: String, CaseIterable, Identifiable {
    case day
    case week

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: return "Day"
        case .week: return "Week"
        }
    }
}

struct EatingReportView: View {
    let snapshot: ReportSnapshot

    @AppStorage("eatingReportShowTimes") private var showTimes = true
    @State private var mode: EatingReportMode = .day
    @State private var selectedDayID: Date?

    private var days: [EatingDaySummary] {
        EatingDaySummary.daysWithIntake(from: snapshot)
    }

    private var weeks: [EatingWeekSummary] {
        EatingWeekSummary.weeks(from: days)
    }

    private var selectedDayBinding: Binding<Date> {
        Binding(
            get: {
                if let selectedDayID, days.contains(where: { DateHelpers.isSameDay($0.date, selectedDayID) }) {
                    return selectedDayID
                }
                return days.last?.date ?? DateHelpers.startOfDay(snapshot.end)
            },
            set: { selectedDayID = $0 }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Mode", selection: $mode) {
                ForEach(EatingReportMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 12)

            if days.isEmpty {
                EmptyReportHint()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                switch mode {
                case .day:
                    dayMode
                case .week:
                    weekMode
                }
            }
        }
        .navigationTitle("What I’ve Been Eating")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Toggle("Show times", isOn: $showTimes)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            if selectedDayID == nil {
                selectedDayID = days.last?.date
            }
        }
    }

    // MARK: - Day mode

    private var dayMode: some View {
        VStack(spacing: 0) {
            dayChrome

            TabView(selection: selectedDayBinding) {
                ForEach(days) { day in
                    ScrollView {
                        EatingDayPage(summary: day, showTimes: showTimes)
                            .padding()
                    }
                    .tag(day.date)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }

    private var dayChrome: some View {
        let selected = selectedDayBinding.wrappedValue
        let index = days.firstIndex(where: { DateHelpers.isSameDay($0.date, selected) }) ?? 0
        let canGoPrev = index > 0
        let canGoNext = index < days.count - 1

        return HStack {
            Button {
                guard canGoPrev else { return }
                selectedDayID = days[index - 1].date
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
            }
            .disabled(!canGoPrev)

            Spacer()

            VStack(spacing: 2) {
                Text(DateHelpers.formattedDay(selected))
                    .font(.headline)
                Text("\(index + 1) of \(days.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                guard canGoNext else { return }
                selectedDayID = days[index + 1].date
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
            }
            .disabled(!canGoNext)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: - Week mode

    private var weekMode: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(weeks.reversed()) { week in
                    EatingWeekCard(week: week) { day in
                        selectedDayID = day.date
                        mode = .day
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Day page

private struct EatingDayPage: View {
    let summary: EatingDaySummary
    let showTimes: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            if !summary.proteins.isEmpty {
                section(title: "Protein", systemImage: "fork.knife.circle") {
                    ReportMetricRow(
                        title: "Total",
                        value: "\(summary.proteinCalories) / \(summary.proteinGoal) kcal",
                        valueColor: proteinValueColor
                    )
                    ForEach(summary.proteins) { protein in
                        proteinRow(protein)
                    }
                }
            }

            if !summary.checklist.isEmpty {
                section(title: "Fats, Veggies & More", systemImage: "leaf") {
                    if summary.vegetableCount > 0 {
                        ReportMetricRow(
                            title: "Vegetables",
                            value: "\(summary.vegetableCount) / \(EatingReportTargets.vegetablesPerDay)",
                            valueColor: IntakeTargetColor.meetingMinimum(
                                current: summary.vegetableCount,
                                minimum: EatingReportTargets.vegetablesPerDay
                            )
                        )
                    }
                    if summary.fatCount > 0 {
                        ReportMetricRow(
                            title: "Fats",
                            value: "\(summary.fatCount)"
                        )
                    }
                    if summary.fruitCount > 0 {
                        ReportMetricRow(
                            title: "Fruits",
                            value: "\(summary.fruitCount)"
                        )
                    }
                    if summary.miscCount > 0 {
                        ReportMetricRow(
                            title: "Misc",
                            value: "\(summary.miscCount) / \(AppLimits.miscDailyLimit)",
                            valueColor: IntakeTargetColor.underMaximum(
                                current: summary.miscCount,
                                maximum: AppLimits.miscDailyLimit
                            )
                        )
                    }
                    ForEach(summary.checklist) { item in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(item.categoryLabel)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 36, alignment: .leading)
                            Text(item.display)
                                .font(.subheadline)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }

            if summary.hydrationOz > 0 || !summary.hydrationSlots.isEmpty {
                section(title: "Hydration", systemImage: "drop.fill") {
                    ReportMetricRow(
                        title: "Total",
                        value: "\(summary.hydrationOz) / \(summary.hydrationTargetOz) oz",
                        valueColor: hydrationValueColor
                    )
                    if summary.proteinDrinkHydrationOz > 0 {
                        ReportMetricRow(
                            title: "Incl. protein drinks",
                            value: "\(summary.proteinDrinkHydrationOz) oz"
                        )
                    }
                    if summary.electrolyteDrinkCount > 0 {
                        ReportMetricRow(
                            title: "Electrolyte drinks",
                            value: "\(summary.electrolyteDrinkCount)"
                        )
                    }
                    ForEach(summary.groupedHydrationSlots) { group in
                        HStack {
                            Text(group.label)
                                .font(.subheadline)
                            Spacer()
                        }
                    }
                }
            }

            if !summary.hasIntake {
                Text("Nothing logged for this day.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        Card {
        VStack(alignment: .leading, spacing: 10) {
            Text(summary.formattedDay)
                .font(.title3.bold())

            ReportMetricRow(
                title: "Protein",
                value: "\(summary.proteinCalories) / \(summary.proteinGoal) kcal",
                valueColor: proteinValueColor
            )
            ReportMetricRow(
                title: "Water",
                value: "\(summary.hydrationOz) / \(summary.hydrationTargetOz) oz",
                valueColor: hydrationValueColor
            )
            if summary.vegetableCount > 0 || !summary.checklist.isEmpty {
                ReportMetricRow(
                    title: "Vegetables",
                    value: "\(summary.vegetableCount) / \(EatingReportTargets.vegetablesPerDay)",
                    valueColor: IntakeTargetColor.meetingMinimum(
                        current: summary.vegetableCount,
                        minimum: EatingReportTargets.vegetablesPerDay
                    )
                )
            }
        }
        }
    }

    private var proteinValueColor: Color {
        IntakeTargetColor.towardTarget(
            current: summary.proteinCalories,
            target: summary.proteinGoal
        )
    }

    private var hydrationValueColor: Color {
        IntakeTargetColor.towardTarget(
            current: summary.hydrationOz,
            target: summary.hydrationTargetOz
        )
    }

    private func section<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Card {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content()
        }
        }
    }

    private func proteinRow(_ protein: EatingProteinRow) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                if showTimes {
                    Text(DateHelpers.formattedTime(protein.time))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: 56, alignment: .leading)
                }
                Text(protein.name)
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                Text("\(protein.calories) kcal")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 0) {
                if showTimes {
                    Color.clear.frame(width: 56)
                }
                Text(protein.servingSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if protein.hydrationOz > 0 {
                    Text(String(format: " · +%.0f oz hydration", protein.hydrationOz))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Week card

private struct EatingWeekCard: View {
    let week: EatingWeekSummary
    let onSelectDay: (EatingDaySummary) -> Void

    var body: some View {
        Card {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(week.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(week.loggedDays) days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                ReportMetricRow(title: "Avg protein", value: String(format: "%.0f kcal", week.avgProtein))
                ReportMetricRow(title: "Avg water", value: String(format: "%.0f oz", week.avgWater))
                ReportMetricRow(title: "Avg veggies", value: String(format: "%.1f / day", week.avgVeggiesPerDay))
            }

            if !week.topProteins.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Top proteins")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(week.topProteins) { item in
                        Text("\(item.name) (\(item.count))")
                            .font(.subheadline)
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(week.days) { day in
                        Button {
                            onSelectDay(day)
                        } label: {
                            VStack(spacing: 2) {
                                Text(day.date.formatted(.dateTime.weekday(.abbreviated)))
                                    .font(.caption2.weight(.semibold))
                                Text(day.date.formatted(.dateTime.day()))
                                    .font(.subheadline.weight(.bold))
                                    .monospacedDigit()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button("View days") {
                if let first = week.days.first {
                    onSelectDay(first)
                }
            }
            .font(.subheadline.weight(.semibold))
        }
        }
    }
}
