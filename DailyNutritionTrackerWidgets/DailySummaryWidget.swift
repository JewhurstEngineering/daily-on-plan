import SwiftUI
import AppIntents
import WidgetKit

/// Hero glance widget: protein & water rings, remaining amounts, core quick-adds.
struct DailySummaryRoot: View {
    @Environment(\.widgetFamily) private var family
    let entry: SectionWidgetEntry

    private var snapshot: DaySnapshot { entry.snapshot }

    private var proteinLeft: Int { max(0, snapshot.proteinGoal - snapshot.proteinCalories) }
    private var waterLeft: Int { max(0, snapshot.waterTargetOz - snapshot.waterOz) }

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                circular
            case .accessoryRectangular:
                rectangular
            case .accessoryInline:
                Text("P \(snapshot.proteinCalories)/\(snapshot.proteinGoal) · H \(snapshot.waterOz)/\(snapshot.waterTargetOz)")
            case .systemSmall:
                small
            case .systemMedium:
                medium
            case .systemLarge, .systemExtraLarge:
                large
            default:
                small
            }
        }
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(AppDeepLink.sectionURL(.dailyStatus))
    }

    // MARK: Lock Screen

    private var circular: some View {
        let combined = min(1, (snapshot.proteinFraction + snapshot.waterFraction) / 2)
        return Gauge(value: combined) {
            Text("Day")
        } currentValueLabel: {
            Text("\(Int(combined * 100))")
                .font(.caption.bold().monospacedDigit())
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }

    private var rectangular: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("P \(snapshot.proteinCalories)/\(snapshot.proteinGoal)")
                    .font(.caption.weight(.semibold).monospacedDigit())
                Text("H \(snapshot.waterOz)/\(snapshot.waterTargetOz)")
                    .font(.caption.weight(.semibold).monospacedDigit())
            }
            Spacer(minLength: 0)
            Text("\(proteinLeft) · \(waterLeft) left")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Button(intent: AddWaterBottleIntent()) {
                Image(systemName: "drop.fill")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add water")
        }
    }

    // MARK: Small — rings only + water

    private var small: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                metricColumn(
                    progress: snapshot.proteinFraction,
                    current: snapshot.proteinCalories,
                    goal: snapshot.proteinGoal,
                    leftText: "\(proteinLeft) left",
                    label: "Protein",
                    tint: .orange,
                    ringSize: 54,
                    warnOver: snapshot.proteinCalories > snapshot.proteinGoal
                )
                metricColumn(
                    progress: snapshot.waterFraction,
                    current: snapshot.waterOz,
                    goal: snapshot.waterTargetOz,
                    leftText: "\(waterLeft) left",
                    label: "Water",
                    tint: .cyan,
                    ringSize: 54,
                    successMet: snapshot.waterOz >= snapshot.waterTargetOz
                )
            }
            .frame(maxHeight: .infinity)

            Button(intent: AddWaterBottleIntent()) {
                Image(systemName: "drop.fill")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)
            .accessibilityLabel("Add \(snapshot.bottleLabel) oz water")
        }
        .padding(2)
    }

    // MARK: Medium — rings + left amounts + 2 actions, no wasted header

    private var medium: some View {
        HStack(alignment: .center, spacing: 14) {
            metricColumn(
                progress: snapshot.proteinFraction,
                current: snapshot.proteinCalories,
                goal: snapshot.proteinGoal,
                leftText: "\(proteinLeft) kcal left",
                label: "Protein",
                tint: .orange,
                ringSize: 72,
                warnOver: snapshot.proteinCalories > snapshot.proteinGoal
            )

            metricColumn(
                progress: snapshot.waterFraction,
                current: snapshot.waterOz,
                goal: snapshot.waterTargetOz,
                leftText: "\(waterLeft) oz left",
                label: "Water",
                tint: .cyan,
                ringSize: 72,
                successMet: snapshot.waterOz >= snapshot.waterTargetOz
            )

            VStack(spacing: 10) {
                compactAction(
                    intent: AddWaterBottleIntent(),
                    systemImage: "drop.fill",
                    tint: .cyan,
                    prominent: true,
                    label: "Add \(snapshot.bottleLabel) oz water"
                )
                Link(destination: AppDeepLink.sectionURL(.protein)) {
                    Image(systemName: "fork.knife")
                        .font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .background(.quaternary.opacity(0.5), in: Circle())
                }
                .tint(.primary)
                .accessibilityLabel("Add protein")

                if snapshot.smokingEnabled {
                    Text("\(snapshot.cigarettes) cig")
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }

    // MARK: Large — rings with left under each, extras + actions

    private var large: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Daily Summary")
                    .font(.headline)
                Spacer()
                Text(DateHelpers.formattedDay(entry.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                metricColumn(
                    progress: snapshot.proteinFraction,
                    current: snapshot.proteinCalories,
                    goal: snapshot.proteinGoal,
                    leftText: "\(proteinLeft) kcal left",
                    label: "Protein",
                    tint: .orange,
                    ringSize: 110,
                    largeLeft: true,
                    warnOver: snapshot.proteinCalories > snapshot.proteinGoal
                )
                metricColumn(
                    progress: snapshot.waterFraction,
                    current: snapshot.waterOz,
                    goal: snapshot.waterTargetOz,
                    leftText: "\(waterLeft) oz left",
                    label: "Hydration",
                    tint: .cyan,
                    ringSize: 110,
                    largeLeft: true,
                    successMet: snapshot.waterOz >= snapshot.waterTargetOz
                )
            }
            .frame(maxWidth: .infinity)

            if hasExtras {
                HStack(spacing: 8) {
                    if snapshot.smokingEnabled {
                        extraChip(icon: "flame.fill", text: "\(snapshot.cigarettes) cigs")
                    }
                    if snapshot.drinkingEnabled {
                        extraChip(icon: "wineglass.fill", text: "\(snapshot.drinks) drinks")
                    }
                    if let w = snapshot.weightLbs {
                        extraChip(icon: "scalemass.fill", text: String(format: "%.0f lb", w))
                    }
                    Spacer(minLength: 0)
                }
            }

            HStack(spacing: 10) {
                Button(intent: AddWaterBottleIntent()) {
                    Image(systemName: "drop.fill")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .accessibilityLabel("Add \(snapshot.bottleLabel) oz water")

                Link(destination: AppDeepLink.sectionURL(.protein)) {
                    Image(systemName: "fork.knife")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .tint(.primary)
                .accessibilityLabel("Add protein")
            }

            Spacer(minLength: 0)
        }
        .padding(8)
    }

    private var hasExtras: Bool {
        snapshot.smokingEnabled || snapshot.drinkingEnabled || snapshot.weightLbs != nil
    }

    // MARK: Building blocks

    private func metricColumn(
        progress: Double,
        current: Int,
        goal: Int,
        leftText: String,
        label: String,
        tint: Color,
        ringSize: CGFloat,
        largeLeft: Bool = false,
        warnOver: Bool = false,
        successMet: Bool = false
    ) -> some View {
        VStack(spacing: largeLeft ? 8 : 4) {
            SummaryRing(
                progress: progress,
                value: "\(current)",
                label: label,
                detail: "/\(goal)",
                tint: tint,
                size: ringSize,
                warnOver: warnOver,
                successMet: successMet
            )

            Text(leftText)
                .font(largeLeft ? .subheadline.weight(.bold).monospacedDigit() : .caption2.weight(.semibold).monospacedDigit())
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
    }

    private func extraChip(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold).monospacedDigit())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.quaternary.opacity(0.4), in: Capsule())
    }

    @ViewBuilder
    private func compactAction<I: AppIntent>(
        intent: I,
        systemImage: String,
        tint: Color,
        prominent: Bool,
        label: String
    ) -> some View {
        let icon = Image(systemName: systemImage)
            .font(.title3.weight(.semibold))
            .frame(width: 44, height: 44)

        if prominent {
            Button(intent: intent) { icon }
                .buttonStyle(.borderedProminent)
                .tint(tint)
                .accessibilityLabel(label)
        } else {
            Button(intent: intent) { icon }
                .buttonStyle(.bordered)
                .tint(tint)
                .accessibilityLabel(label)
        }
    }
}

// MARK: - Compact ring for widgets

struct SummaryRing: View {
    let progress: Double
    let value: String
    let label: String
    var detail: String? = nil
    var tint: Color = .accentColor
    var size: CGFloat = 56
    var warnOver: Bool = false
    var successMet: Bool = false

    private var ringColor: Color {
        if warnOver { return .red.opacity(0.9) }
        if successMet { return .green }
        return tint
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.12), lineWidth: max(5, size * 0.09))
                Circle()
                    .trim(from: 0, to: min(max(progress, 0), 1))
                    .stroke(
                        ringColor,
                        style: StrokeStyle(lineWidth: max(5, size * 0.09), lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text(value)
                        .font(size >= 100 ? .title2.bold().monospacedDigit() : (size >= 70 ? .callout.bold().monospacedDigit() : .caption.bold().monospacedDigit()))
                        .foregroundStyle(warnOver ? Color.red.opacity(0.9) : .primary)
                        .minimumScaleFactor(0.55)
                        .lineLimit(1)
                    if let detail {
                        Text(detail)
                            .font(.system(size: max(8, size * 0.12)).weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .padding(size * 0.16)
            }
            .frame(width: size, height: size)

            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(value)\(detail ?? "")")
    }
}
