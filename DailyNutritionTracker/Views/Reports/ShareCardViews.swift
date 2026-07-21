import SwiftUI
import UIKit

enum ShareCardRenderer {
    @MainActor
    static func writePNG<V: View>(of view: V, size: CGSize) -> URL? {
        let root = view
            .frame(width: size.width, height: size.height)
            .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: root)
        renderer.scale = 3
        guard let image = renderer.uiImage, let data = image.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("daily-on-plan-share-\(UUID().uuidString).png")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

// MARK: - Cards

struct TodayShareCard: View {
    let date: Date
    let followedPlan: Bool
    let protein: Int
    let proteinGoal: Int
    let waterOz: Int
    let waterTarget: Int
    let weightLabel: String?
    let toGoLabel: String?
    let brand: String

    var body: some View {
        ShareCardChrome(brand: brand, title: "Today", subtitle: date.formatted(.dateTime.weekday(.wide).month().day())) {
            VStack(alignment: .leading, spacing: 14) {
                row("Plan", followedPlan ? "Followed" : "Off-plan", accent: followedPlan)
                row("Protein", "\(protein) / \(proteinGoal) kcal", accent: protein > 0 && protein <= proteinGoal)
                row("Water", "\(waterOz) / \(waterTarget) oz", accent: waterOz >= waterTarget)
                if let weightLabel {
                    row("Weight", weightLabel, accent: true)
                }
                if let toGoLabel {
                    row("To go", toGoLabel, accent: true)
                }
            }
        }
    }

    private func row(_ title: String, _ value: String, accent: Bool) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Color.onPlanMuted)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(accent ? Color.onPlanInk : Color.orange)
        }
        .font(.system(size: 16, weight: .medium, design: .rounded))
    }
}

struct StreakShareCard: View {
    let planStreak: Int
    let smokeFreeStreak: Int?
    let alcoholFreeStreak: Int?
    let brand: String

    var body: some View {
        ShareCardChrome(brand: brand, title: "Streaks", subtitle: "Keep going") {
            VStack(alignment: .leading, spacing: 16) {
                if let smokeFreeStreak, smokeFreeStreak > 0 {
                    streakRow(title: "Smoke-free", days: smokeFreeStreak)
                }
                if let alcoholFreeStreak, alcoholFreeStreak > 0 {
                    streakRow(title: "Alcohol-free", days: alcoholFreeStreak)
                }
                if (smokeFreeStreak ?? 0) == 0, (alcoholFreeStreak ?? 0) == 0 {
                    streakRow(title: "Followed plan", days: planStreak)
                } else if planStreak > 0 {
                    streakRow(title: "Followed plan", days: planStreak)
                }
            }
        }
    }

    private func streakRow(title: String, days: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.onPlanMuted)
            Text("\(days)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(Color.onPlanInk)
            Text(days == 1 ? "day in a row" : "days in a row")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.onPlanBlue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct HeatmapShareCard: View {
    let month: Date
    let metric: HeatmapMetric
    let days: [HeatmapDay]
    let brand: String

    var body: some View {
        ShareCardChrome(
            brand: brand,
            title: metric.title,
            subtitle: month.formatted(.dateTime.month(.wide).year())
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HeatmapMonthGrid(
                    month: month,
                    days: days,
                    accent: Color.onPlanBlue,
                    cellSize: 24,
                    showWeekdayLabels: true
                )
                HStack(spacing: 10) {
                    legendDot(Color.onPlanBlue.opacity(0.85), "Hit")
                    legendDot(Color.orange.opacity(0.75), "Miss")
                    legendDot(Color.onPlanSilver.opacity(0.6), "No log")
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color.onPlanMuted)
            }
        }
    }

    private func legendDot(_ color: Color, _ title: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(title)
        }
    }
}

private struct ShareCardChrome<Content: View>: View {
    let brand: String
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.onPlanLight, Color.white, Color(hex: "#E8F4FF")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    Text(brand)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.onPlanNavy)
                    Spacer()
                    Text(title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.onPlanBlue)
                }
                Text(subtitle)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.onPlanMuted)
                content
                Spacer(minLength: 0)
                Text(AppIdentity.tagline)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.onPlanMuted)
            }
            .padding(24)
        }
    }
}

enum ShareCardBuilder {
    @MainActor
    static func todayURL(from snapshot: ReportSnapshot) -> URL? {
        let log = snapshot.logForEndDate
        let settings = snapshot.settings
        let unit = settings.usesMetricWeight ? "kg" : "lb"
        var weightLabel: String?
        var toGoLabel: String?
        if let w = snapshot.weightForEndDate {
            let display = settings.usesMetricWeight ? w.weightLbs * 0.453592 : w.weightLbs
            weightLabel = String(format: "%.1f %@", display, unit)
            if let goal = settings.goalWeightLbs {
                let delta = settings.usesMetricWeight
                    ? (w.weightLbs - goal) * 0.453592
                    : (w.weightLbs - goal)
                if abs(delta) < 0.05 {
                    toGoLabel = "At goal"
                } else if delta > 0 {
                    toGoLabel = String(format: "%.1f %@ to go", delta, unit)
                } else {
                    toGoLabel = String(format: "%.1f %@ under", abs(delta), unit)
                }
            }
        }
        let card = TodayShareCard(
            date: snapshot.end,
            followedPlan: log?.followedPlan ?? false,
            protein: log?.totalProteinCalories ?? 0,
            proteinGoal: log?.proteinGoal ?? settings.defaultProteinGoal,
            waterOz: log?.waterOz ?? 0,
            waterTarget: settings.hydrationTargetOz,
            weightLabel: weightLabel,
            toGoLabel: toGoLabel,
            brand: AppIdentity.displayName
        )
        return ShareCardRenderer.writePNG(of: card, size: CGSize(width: 360, height: 420))
    }

    @MainActor
    static func streakURL(from snapshot: ReportSnapshot) -> URL? {
        let smoke: Int? = snapshot.settings.smokingMode.showsSection
            ? snapshot.currentSmokeFreeStreak
            : nil
        let alcohol: Int? = snapshot.settings.drinkingMode.showsSection
            ? snapshot.currentAlcoholFreeStreak
            : nil
        let card = StreakShareCard(
            planStreak: snapshot.currentPlanFollowStreak,
            smokeFreeStreak: smoke,
            alcoholFreeStreak: alcohol,
            brand: AppIdentity.displayName
        )
        return ShareCardRenderer.writePNG(of: card, size: CGSize(width: 360, height: 420))
    }
}
