import SwiftUI
import OnPlanCore

struct MenuBarPreviewStrip: View {
    let snapshot: ChromeSnapshot
    let preferences: DisplayPreferences
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark = colorScheme == .dark
        let barFill = dark
            ? Color(red: 0.14, green: 0.14, blue: 0.14)
            : Color(red: 0.91, green: 0.90, blue: 0.87)
        let fg = dark ? Color.white.opacity(0.92) : Color.black.opacity(0.82)
        let segments = MenuBarFormatter.segments(snapshot: snapshot, preferences: preferences)
        VStack(alignment: .leading, spacing: 6) {
            Text("Menu bar")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 5) {
                AppLogo(size: 14)
                if preferences.showInMenuBar {
                    ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                        if index > 0 {
                            Text("·")
                                .foregroundStyle(fg.opacity(0.7))
                        }
                        HStack(spacing: 2) {
                            if let icon = segment.systemImage {
                                Image(systemName: icon)
                                    .foregroundStyle(fg)
                            }
                            if !segment.text.isEmpty {
                                Text(segment.text)
                                    .foregroundStyle(fg)
                            }
                        }
                    }
                    .lineLimit(1)
                } else {
                    Text("(icon only)")
                        .foregroundStyle(fg.opacity(0.7))
                }
                Spacer(minLength: 0)
            }
            .font(.caption.weight(.medium).monospacedDigit())
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(barFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }
}

struct PopoverPreviewCard: View {
    let snapshot: ChromeSnapshot
    let preferences: DisplayPreferences
    @Environment(\.appTheme) private var theme

    var body: some View {
        let t = preferences.popover
        VStack(alignment: .leading, spacing: 6) {
            Text("Popover")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 8) {
                    AppLogo(size: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(AppIdentity.displayName)
                            .font(.caption.weight(.semibold))
                        Text("Updated now")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if t.followedPlan || t.ketosis {
                    HStack(spacing: 10) {
                        if t.followedPlan {
                            Label(
                                snapshot.followedPlan ? "On plan" : "Off plan",
                                systemImage: snapshot.followedPlan ? "checkmark.seal.fill" : "xmark.seal"
                            )
                            .foregroundStyle(snapshot.followedPlan ? theme.plan : .secondary)
                        }
                        if t.ketosis {
                            Label(
                                snapshot.ketosis ? "Ketosis" : "No ketosis",
                                systemImage: snapshot.ketosis ? "flame.fill" : "flame"
                            )
                            .foregroundStyle(snapshot.ketosis ? theme.ok : .secondary)
                        }
                    }
                    .font(.caption.weight(.semibold))
                }

                if t.protein {
                    previewPool(
                        title: "Protein",
                        icon: "fork.knife",
                        value: "\(snapshot.proteinCalories) / \(snapshot.proteinGoal)",
                        percent: snapshot.proteinPercent,
                        tint: theme.protein
                    )
                }
                if t.water {
                    previewPool(
                        title: "Water",
                        icon: "drop.fill",
                        value: "\(snapshot.waterOz) / \(snapshot.waterTargetOz) oz",
                        percent: snapshot.waterPercent,
                        tint: theme.water
                    )
                }

                if t.fasting, snapshot.fastingEnabled {
                    Text(snapshot.fastingStatusLine.isEmpty ? "Fasting" : snapshot.fastingStatusLine)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                let smoking = t.smoking && snapshot.smokingEnabled
                let drinking = t.drinking && snapshot.drinkingEnabled
                let bathroom = t.bathroom && snapshot.bathroomEnabled
                if smoking || drinking || bathroom {
                    HStack(spacing: 10) {
                        if smoking {
                            Label("\(snapshot.cigarettes)", systemImage: "flame")
                        }
                        if drinking {
                            Label("\(snapshot.drinks)", systemImage: "wineglass")
                        }
                        if bathroom {
                            Label("U \(snapshot.urineCount) · S \(snapshot.stoolCount)", systemImage: "toilet")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                if !t.followedPlan && !t.ketosis && !t.protein && !t.water
                    && !smoking && !drinking && !bathroom && !(t.fasting && snapshot.fastingEnabled)
                {
                    Text("Enable a Popover metric above to preview it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }

    private func previewPool(
        title: String,
        icon: String,
        value: String,
        percent: Double,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                    .frame(width: 12)
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(value)
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(tint)
            }
            UsageProgressBar(percent: percent, tint: tint, pattern: .forPool(title))
                .frame(height: 6)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(0.08))
        )
    }
}
