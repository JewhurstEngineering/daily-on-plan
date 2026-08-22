import SwiftUI
import SwiftData
import OnPlanCore

/// Where a tap on the Today screen goes. Today shows summaries only — every logging
/// surface is one push away, so the screen itself never grows past one phone height.
enum TodayDestination: Hashable {
    case weight
    case protein
    case hydration
    case alsoToday
    case section(DaySectionID)
}

// MARK: - Compact ring

/// The 64pt ring used on Today's goal cards. `GoalRingView` is the 110pt ring with the
/// value printed inside it; at this size only a percentage fits.
struct CompactGoalRing: View {
    let current: Int
    let goal: Int
    var tint: Color
    var metTint: Color
    var overTint: Color?
    var caption: String
    /// Fractions of the full ring (0...1) drawn on top of the fill.
    var electrolyteSegments: [(start: Double, end: Double)] = []
    var size: CGFloat = 56

    private var ratio: Double {
        guard goal > 0 else { return 0 }
        return Double(current) / Double(goal)
    }

    private var isMet: Bool { goal > 0 && current >= goal }
    private var isOver: Bool { current > goal }

    private var strokeColor: Color {
        if isOver, let overTint { return overTint }
        return isMet ? metTint : tint
    }

    private var lineWidth: CGFloat { size * 0.11 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.onPlanHairline, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: min(max(ratio, 0), 1))
                .stroke(strokeColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: current)

            ForEach(Array(electrolyteSegments.enumerated()), id: \.offset) { _, segment in
                Circle()
                    .trim(from: segment.start, to: segment.end)
                    .stroke(Color.yellow.opacity(0.95), style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }

            VStack(spacing: 1) {
                Text("\(Int((ratio * 100).rounded()))%")
                    .font(.subheadline.bold().monospacedDigit())
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(caption)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, lineWidth)
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel("\(current) of \(goal) \(caption)")
    }
}

// MARK: - Weight

/// Today's weight summary. Reading it is the common case, so the figure leads; the
/// masked state keeps the same footprint so revealing never reflows Today.
struct TodayWeightCard: View {
    let weight: WeightEntry?
    let recentWeights: [WeightEntry]
    @Bindable var settings: AppSettings
    let masking: WeightMasking
    let onOpen: () -> Void
    let onLog: () -> Void

    @Environment(\.appTheme) private var appTheme

    private var unitLabel: String { settings.usesMetricWeight ? "kg" : "lb" }

    private func display(_ lbs: Double) -> Double {
        settings.usesMetricWeight ? lbs * 0.45359237 : lbs
    }

    private var bmi: Double? {
        guard let weight else { return nil }
        return BMICalculator.bmi(weightLbs: weight.weightLbs, heightInches: settings.heightInches)
    }

    /// Change against the most recent earlier entry, which is what "since last weigh-in" means.
    private var delta: Double? {
        guard let weight,
              let prior = recentWeights.first(where: { $0.date < weight.date }) else { return nil }
        return display(weight.weightLbs - prior.weightLbs)
    }

    private var toGoalText: String? {
        guard let goal = settings.goalWeightLbs, let weight else { return nil }
        let remaining = weight.weightLbs - goal
        guard remaining > 0.05 else { return "At goal" }
        return String(format: "%.0f %@ to goal", display(remaining), unitLabel)
    }

    private var subtitle: String {
        if masking.isMasked { return "Tap to show weight & BMI" }
        var parts: [String] = []
        if let bmi { parts.append(String(format: "BMI %.1f", bmi)) }
        if let toGoalText { parts.append(toGoalText) }
        if parts.isEmpty { parts.append(settings.hasHeight ? "No weight logged today" : "Set your height for BMI") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        Card {
            HStack(spacing: Spacing.l) {
                VStack(alignment: .leading, spacing: 3) {
                    PrivateFigure(
                        isMasked: masking.isMasked,
                        accessibilityLabelWhenMasked: "Weight hidden. Double tap to show."
                    ) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(weight.map { String(format: "%.1f", display($0.weightLbs)) } ?? "—")
                                .font(.system(size: 34, weight: .bold, design: .default).monospacedDigit())
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .layoutPriority(1)
                            Text(unitLabel)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .fixedSize()
                            if let delta, !masking.isMasked {
                                DeltaPill(value: delta, unit: unitLabel, good: appTheme.ok)
                                    .fixedSize()
                            }
                        }
                    }

                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: Spacing.s)

                if recentWeights.count > 1 {
                    WeightSparkline(
                        values: recentWeights.reversed().map { display($0.weightLbs) },
                        tint: masking.isMasked ? Color.secondary.opacity(0.25) : appTheme.tint,
                        showsEndpoint: !masking.isMasked
                    )
                    .frame(width: 72, height: 38)
                }

                if masking.canHide {
                    // Revealed for now — give the way back, next to the value it hides.
                    Button(action: masking.hide) {
                        Image(systemName: "eye.slash")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Hide weight again")
                } else if weight == nil {
                    Button(action: onLog) {
                        Text("Log")
                            .font(.subheadline.weight(.semibold))
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if masking.isMasked {
                    masking.reveal()
                } else {
                    onOpen()
                }
            }
            .contextMenu {
                if masking.canHide {
                    Button {
                        masking.hide()
                    } label: {
                        Label("Hide weight", systemImage: "eye.slash")
                    }
                }
                if masking.isMasked {
                    Button {
                        masking.reveal()
                    } label: {
                        Label("Show weight", systemImage: "eye")
                    }
                }
                Button(action: onOpen) {
                    Label("Open weight & BMI", systemImage: "scalemass")
                }
            }
        }
    }
}

private struct DeltaPill: View {
    let value: Double
    let unit: String
    let good: Color

    private var isDown: Bool { value < 0 }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: isDown ? "arrow.down" : "arrow.up")
                .font(.system(size: 10, weight: .bold))
            Text(String(format: "%.1f", abs(value)))
                .font(.caption.weight(.bold).monospacedDigit())
        }
        .foregroundStyle(isDown ? good : Color.secondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            (isDown ? good : Color.secondary).opacity(0.16),
            in: RoundedRectangle(cornerRadius: 7, style: .continuous)
        )
        .accessibilityLabel("\(isDown ? "down" : "up") \(String(format: "%.1f", abs(value))) \(unit)")
    }
}

/// Trend shape only — no axis, no readable values, so it stays up while the figure is masked.
struct WeightSparkline: View {
    let values: [Double]
    let tint: Color
    var showsEndpoint: Bool = true
    /// Floor on the plotted range, in display units. Without it, min/max normalisation
    /// makes an ordinary day-to-day wobble fill the whole box and read as a crash.
    var minimumSpan: Double = 8

    var body: some View {
        GeometryReader { geo in
            let points = layout(in: geo.size)
            ZStack {
                if points.count > 1 {
                    Path { path in
                        path.move(to: points[0])
                        for point in points.dropFirst() { path.addLine(to: point) }
                    }
                    .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    if showsEndpoint, let last = points.last {
                        Circle()
                            .fill(tint)
                            .frame(width: 6, height: 6)
                            .position(last)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func layout(in size: CGSize) -> [CGPoint] {
        let series = Array(values.suffix(30))
        guard series.count > 1 else { return [] }
        let minValue = series.min() ?? 0
        let maxValue = series.max() ?? 1
        // Centre the real range inside at least `minimumSpan`, so the line sits mid-box
        // and its steepness stays honest.
        let actualSpan = maxValue - minValue
        let span = max(actualSpan, minimumSpan)
        let pad = (span - actualSpan) / 2
        let floorValue = minValue - pad
        let stepX = size.width / CGFloat(series.count - 1)
        return series.enumerated().map { index, value in
            CGPoint(
                x: CGFloat(index) * stepX,
                y: size.height - CGFloat((value - floorValue) / span) * size.height
            )
        }
    }
}

// MARK: - Goal cards

/// A ring, its numbers and the button that changes them, in one row. The old design put
/// the rings in a separate Goals card, which meant scrolling past them to log anything.
struct TodayGoalCard<MenuContent: View>: View {
    let title: String
    let current: Int
    let goal: Int
    let unit: String
    let subtitle: String
    let ringCaption: String
    let tint: Color
    let metTint: Color
    var overTint: Color?
    var badge: String?
    var electrolyteSegments: [(start: Double, end: Double)] = []
    let actionTitle: String
    let actionIsProminent: Bool
    /// Last seven days, oldest first. Empty hides the strip.
    var weekValues: [Double] = []
    var weekOverTint: Color?
    var weekShortTint: Color?
    let onAction: () -> Void
    let onOpen: () -> Void
    /// Long-press menu on the action button: the quick options you would otherwise
    /// go to the full screen for.
    @ViewBuilder var actionMenu: () -> MenuContent

    var body: some View {
        Card {
            VStack(spacing: Spacing.s) {
            HStack(spacing: Spacing.l) {
                CompactGoalRing(
                    current: current,
                    goal: goal,
                    tint: tint,
                    metTint: metTint,
                    overTint: overTint,
                    caption: ringCaption,
                    electrolyteSegments: electrolyteSegments
                )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                        if let badge {
                            Text(badge)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(metTint)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(metTint.opacity(0.16), in: Capsule())
                        }
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(current)")
                            .font(.title2.bold().monospacedDigit())
                        Text("/ \(goal) \(unit)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(perform: onOpen)

                Button(action: onAction) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.footnote.weight(.bold))
                        Text(actionTitle)
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(actionIsProminent ? tint : tint.opacity(0.18))
                .foregroundStyle(actionIsProminent ? Color.white : tint)
                .contextMenu { actionMenu() }
                .accessibilityHint("Double tap to log. Touch and hold for more options.")
            }

            if !weekValues.isEmpty {
                MiniTrendStrip(
                    values: weekValues,
                    goal: Double(goal),
                    tint: tint,
                    overTint: weekOverTint,
                    shortTint: weekShortTint
                )
                .onTapGesture(perform: onOpen)
            }
            }
        }
    }
}

// MARK: - Also today

/// Everything optional, one line each. Replaces eight separate collapsible cards —
/// see the redesign canvas, "Also today".
struct AlsoTodayCard: View {
    @Bindable var settings: AppSettings
    @Bindable var log: DailyLog
    let onSelect: (DaySectionID) -> Void
    let onSeeAll: () -> Void

    /// The three most useful rows for Today; the rest live behind "See all".
    private var previewSections: [DaySectionID] {
        Array(AlsoTodayCatalog.sections(for: settings).prefix(3))
    }

    var body: some View {
        Card {
            VStack(spacing: 0) {
                HStack {
                    Text("ALSO TODAY")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("See all", action: onSeeAll)
                        .font(.subheadline)
                }
                .padding(.bottom, Spacing.s)

                ForEach(previewSections, id: \.self) { section in
                    Divider()
                    AlsoTodayRow(section: section, settings: settings, log: log) {
                        onSelect(section)
                    }
                }
            }
        }
    }
}

struct AlsoTodayRow: View {
    let section: DaySectionID
    @Bindable var settings: AppSettings
    @Bindable var log: DailyLog
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.m) {
                Image(systemName: section.systemImage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                Text(section.settingsTitle)
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer(minLength: Spacing.s)
                let summary = AlsoTodayCatalog.summary(for: section, settings: settings, log: log)
                Text(summary.text)
                    .font(.subheadline)
                    .foregroundStyle(summary.isEmpty ? .tertiary : .secondary)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Which optional sections are on, and the one-line value each shows on Today.
enum AlsoTodayCatalog {
    /// Everything that is not one of Today's three headline cards or the daily ritual,
    /// filtered to what the viewer actually has switched on.
    static func sections(for settings: AppSettings) -> [DaySectionID] {
        let optional: [DaySectionID] = [
            .fasting, .checklist, .workouts, .feelings,
            .smoking, .drinking, .bathroom, .supplements
        ]
        return optional.filter { settings.isSectionVisible($0) }
    }

    struct Summary {
        let text: String
        let isEmpty: Bool
    }

    static func summary(for section: DaySectionID, settings: AppSettings, log: DailyLog) -> Summary {
        switch section {
        case .fasting:
            return Summary(text: settings.fastingEnabled ? "On" : "Off", isEmpty: !settings.fastingEnabled)
        case .checklist:
            let checked = log.checkedFatsAndVeggies.count
                + log.checkedFats.count
                + log.checkedMiscItems.count
                + log.checkedFruits.count
            return count(checked, noun: "item")
        case .workouts:
            return count(log.workoutEntries?.count ?? 0, noun: "workout")
        case .feelings:
            return count(log.feelingEntries?.count ?? 0, noun: "entry", plural: "entries")
        case .smoking:
            return count(log.cigarettesSmoked, noun: "cig")
        case .drinking:
            return count(log.drinksLogged, noun: "drink")
        case .bathroom:
            return count(log.bathroomEvents.count, noun: "visit")
        case .supplements:
            return count(log.completedSupplements.count, noun: "taken", plural: "taken")
        default:
            return Summary(text: "", isEmpty: true)
        }
    }

    private static func count(_ value: Int, noun: String, plural: String? = nil) -> Summary {
        guard value > 0 else { return Summary(text: "Not logged", isEmpty: true) }
        let word = value == 1 ? noun : (plural ?? noun + "s")
        return Summary(text: "\(value) \(word)", isEmpty: false)
    }
}

// MARK: - Date bar

struct TodayDateBar: View {
    @Binding var selectedDate: Date

    private var isToday: Bool { Calendar.current.isDateInToday(selectedDate) }

    var body: some View {
        HStack {
            Button {
                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Previous day")

            Spacer()

            VStack(spacing: 1) {
                Text(DateHelpers.formattedDay(selectedDate))
                    .font(.subheadline.weight(.semibold))
                if !isToday {
                    Button("Back to today") { selectedDate = Date() }
                        .font(.caption)
                }
            }
            .foregroundStyle(isToday ? .secondary : .primary)

            Spacer()

            Button {
                selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(isToday ? .tertiary : .secondary)
            .disabled(isToday || selectedDate > Date())
            .accessibilityLabel("Next day")
        }
    }
}

// MARK: - Daily ritual

/// The two toggles done every day. Everything else that used to sit in the Daily Status
/// header — notes, off-plan reasons, ketone reading, eating window — is one push away
/// under "Day details", so it stops competing with logging for the top of the screen.
struct TodayRitualCard: View {
    @Bindable var log: DailyLog
    let onOpenDetails: () -> Void

    @Environment(\.appTheme) private var appTheme

    var body: some View {
        Card {
            VStack(spacing: 0) {
                Toggle(isOn: $log.followedPlan) {
                    Text("Followed plan")
                        .font(.body)
                }
                .tint(appTheme.ok)
                .frame(height: 40)

                Divider()

                Toggle(isOn: $log.ketosis) {
                    Text("Ketosis")
                        .font(.body)
                }
                .tint(appTheme.tint)
                .frame(height: 40)

                Divider()

                Button(action: onOpenDetails) {
                    HStack(spacing: Spacing.m) {
                        Text("Day details")
                            .font(.body)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(detailsSummary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var detailsSummary: String {
        let trimmed = log.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Notes, off-plan, ketones" : trimmed
    }
}

// MARK: - Mini trend

/// A fortnight meter for a goal card: one equal block per day, coloured by whether that
/// day met its goal. Height carries no meaning — the colour is the whole message.
///
/// Deliberately not a bar chart. The full magnitudes live on Trends; here the question is
/// only "how many of the last fourteen days went well", which reads faster as a run of
/// blocks than as a row of differing heights.
struct MiniTrendStrip: View {
    /// Oldest first, one entry per day, `0` for a day with nothing logged.
    let values: [Double]
    let goal: Double
    let tint: Color
    /// Set for a ceiling goal (protein): days above the line read as a warning.
    var overTint: Color?
    /// Set for a floor goal (hydration): days below the line read as short.
    var shortTint: Color?
    var height: CGFloat = 20

    private func color(for value: Double) -> Color {
        guard value > 0 else { return Color.onPlanHairline.opacity(0.6) }
        if let overTint { return value > goal ? overTint : tint }
        if let shortTint { return value >= goal ? tint : shortTint }
        return value >= goal ? tint : tint.opacity(0.3)
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(color(for: value))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let logged = values.filter { $0 > 0 }.count
        let cleared = overTint != nil
            ? values.filter { $0 > 0 && $0 <= goal }.count
            : values.filter { $0 >= goal }.count
        return "Last \(values.count) days: \(cleared) of \(logged) logged days on target"
    }
}
