import SwiftUI
import AppKit
import OnPlanCore

struct MenuBarPopoverView: View {
    @EnvironmentObject private var store: OnPlanStore
    @Environment(\.appTheme) private var theme
    @State private var statusMessage: String?
    @State private var isRefreshing = false
    @State private var statusTick = 0

    private var snapshot: ChromeSnapshot { store.snapshot }
    private var toggles: DisplayPreferences.SurfaceToggles { store.preferences.popover }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                flags
                if toggles.protein {
                    metricRow(
                        title: "Protein",
                        systemImage: "fork.knife",
                        value: "\(snapshot.proteinCalories) / \(snapshot.proteinGoal)",
                        percent: snapshot.proteinPercent,
                        tint: theme.protein
                    )
                }
                if toggles.water {
                    metricRow(
                        title: "Water",
                        systemImage: "drop.fill",
                        value: "\(snapshot.waterOz) / \(snapshot.waterTargetOz) oz",
                        percent: snapshot.waterPercent,
                        tint: theme.water
                    )
                }
                counts
                quickAdds
                if let statusMessage {
                    Text(statusMessage)
                        .appFont(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            footer
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .appThemed(store.preferences)
        .appIntrinsicScale(store.preferences.interfaceSize.scale)
        .onAppear {
            MacDaySync.refresh(store: store)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            AppLogo(size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(AppIdentity.displayName)
                    .appFont(.headline)
                if snapshot.generatedAt == .distantPast {
                    Text("Open to sync")
                        .appFont(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Updated \(snapshot.generatedAt.formatted(date: .omitted, time: .shortened))")
                        .appFont(.caption)
                        .foregroundStyle(snapshot.isStale ? .orange : .secondary)
                }
                Text(iCloudStatusLine)
                    .appFont(.caption2)
                    .foregroundStyle(SharedModelContainer.usesCloudKit ? Color.secondary : Color.orange)
                    .id(statusTick)
            }
            Spacer(minLength: 0)
            Button(action: refreshFromiCloud) {
                if isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .buttonStyle(.borderless)
            .help("Check iCloud")
            .disabled(isRefreshing)
            .keyboardShortcut("r", modifiers: .command)
        }
    }

    private var iCloudStatusLine: String {
        if SharedModelContainer.usesCloudKit {
            return "iCloud on"
        }
        if let error = SharedModelContainer.cloudKitError {
            return "iCloud off: \(error)"
        }
        return "iCloud off"
    }

    private func refreshFromiCloud() {
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            _ = try SharedModelContainer.reopen()
        } catch {
            statusMessage = SharedModelContainer.describe(error)
        }
        MacDaySync.refresh(store: store)
        statusTick += 1
        if SharedModelContainer.usesCloudKit {
            statusMessage = "Checked iCloud."
        } else if statusMessage == nil, let error = SharedModelContainer.cloudKitError {
            statusMessage = error
        }
    }

    @ViewBuilder
    private var flags: some View {
        if toggles.followedPlan || toggles.ketosis {
            HStack(spacing: 12) {
                if toggles.followedPlan {
                    Label(
                        snapshot.followedPlan ? "On plan" : "Off plan",
                        systemImage: snapshot.followedPlan ? "checkmark.seal.fill" : "xmark.seal"
                    )
                    .foregroundStyle(snapshot.followedPlan ? theme.plan : .secondary)
                }
                if toggles.ketosis {
                    Label(
                        snapshot.ketosis ? "Ketosis" : "No ketosis",
                        systemImage: snapshot.ketosis ? "flame.fill" : "flame"
                    )
                    .foregroundStyle(snapshot.ketosis ? theme.ok : .secondary)
                }
            }
            .appFont(.subheadline, weight: .semibold)
        }
    }

    @ViewBuilder
    private var counts: some View {
        let smoking = toggles.smoking && snapshot.smokingEnabled
        let drinking = toggles.drinking && snapshot.drinkingEnabled
        let bathroom = toggles.bathroom && snapshot.bathroomEnabled
        if smoking || drinking || bathroom {
            HStack(spacing: 12) {
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
            .appFont(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var quickAdds: some View {
        HStack(spacing: 6) {
            Button("Water") { apply(QuickAddService.addWaterBottle()) }
            if snapshot.smokingEnabled {
                Button("Cig") { apply(QuickAddService.addCigarette()) }
            }
            if snapshot.drinkingEnabled {
                Button("Drink") { apply(QuickAddService.addDrinks(1)) }
            }
            if snapshot.bathroomEnabled {
                Button("Urine") { apply(QuickAddService.addBathroom(kind: .urine)) }
                Button("Stool") { apply(QuickAddService.addBathroom(kind: .stool)) }
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private var footer: some View {
        HStack {
            SettingsOpenLink {
                Label("Settings", systemImage: "gearshape")
            }
            .keyboardShortcut(",", modifiers: .command)
            Spacer(minLength: 8)
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "xmark.circle")
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .overlay {
            Text(AppAbout.organization)
                .appFont(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .allowsHitTesting(false)
        }
        .labelStyle(.titleAndIcon)
        .controlSize(.small)
    }

    private func metricRow(
        title: String,
        systemImage: String,
        value: String,
        percent: Double,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                    .frame(width: 16)
                Text(title)
                    .appFont(.subheadline, weight: .semibold)
                Spacer()
                Text(value)
                    .appFont(.caption, weight: .semibold, mono: true)
                    .foregroundStyle(tint)
            }
            UsageProgressBar(percent: percent, tint: tint, pattern: .forPool(title))
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.opacity(0.08))
        )
    }

    private func apply(_ result: QuickAddService.Result) {
        switch result {
        case .success(let message), .failure(let message):
            statusMessage = message
        }
        MacDaySync.refresh(store: store)
    }
}
