import SwiftUI
import WatchConnectivity

@main
struct DailyNutritionTrackerWatchApp: App {
    @StateObject private var connectivity = WatchConnectivityClient.shared

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(connectivity)
                .onAppear {
                    connectivity.activate()
                }
        }
    }
}

struct WatchRootView: View {
    @EnvironmentObject private var connectivity: WatchConnectivityClient
    @State private var page = 0

    var body: some View {
        TabView(selection: $page) {
            WatchSummaryView()
                .tag(0)
            WatchActionsView {
                page = 0
            }
            .tag(1)
        }
        #if os(watchOS)
        .tabViewStyle(.verticalPage)
        #else
        .tabViewStyle(.page)
        #endif
    }
}

struct WatchSummaryView: View {
    @EnvironmentObject private var connectivity: WatchConnectivityClient

    private var snapshot: WatchDaySnapshot { connectivity.snapshot }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                HStack {
                    Text("Today")
                        .font(.headline)
                    Spacer()
                    if !connectivity.isReachable {
                        Image(systemName: "iphone.slash")
                            .foregroundStyle(.orange)
                    }
                }

                HStack(spacing: 8) {
                    watchRing(
                        progress: snapshot.proteinFraction,
                        value: "\(snapshot.proteinCalories)",
                        detail: "/\(snapshot.proteinGoal)",
                        label: "Protein",
                        tint: .orange
                    )
                    watchRing(
                        progress: snapshot.waterFraction,
                        value: "\(snapshot.waterOz)",
                        detail: "/\(snapshot.waterTargetOz)",
                        label: "Water",
                        tint: .cyan
                    )
                }

                VStack(spacing: 4) {
                    Text("\(snapshot.proteinLeft) kcal left")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.orange)
                    Text("\(snapshot.waterLeft) oz left")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.cyan)
                }

                HStack(spacing: 8) {
                    Image(systemName: snapshot.followedPlan ? "checkmark.seal.fill" : "xmark.seal")
                        .foregroundStyle(snapshot.followedPlan ? .green : .secondary)
                    Image(systemName: snapshot.ketosis ? "flame.fill" : "flame")
                        .foregroundStyle(snapshot.ketosis ? .orange : .secondary)
                }
                .font(.caption)

                if snapshot.isStale || snapshot.updatedAt == .distantPast {
                    Text("Open iPhone to sync")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let error = connectivity.lastError {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func watchRing(
        progress: Double,
        value: String,
        detail: String,
        label: String,
        tint: Color
    ) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.15), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: min(max(progress, 0), 1))
                    .stroke(tint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text(value)
                        .font(.caption.bold().monospacedDigit())
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text(detail)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .padding(6)
            }
            .frame(width: 64, height: 64)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct WatchActionsView: View {
    @EnvironmentObject private var connectivity: WatchConnectivityClient
    var onLogged: () -> Void
    @State private var nestedAction: String?

    private var snapshot: WatchDaySnapshot { connectivity.snapshot }
    private var busy: Bool { !connectivity.isReachable || connectivity.isSending }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if let nestedAction {
                    nestedPage(for: nestedAction)
                } else {
                    rootPage
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var rootPage: some View {
        VStack(spacing: 8) {
            Text("Quick Add")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(snapshot.resolvedQuickAddSlots, id: \.self) { slot in
                let meta = WatchQuickAddMeta(slot)
                actionButton(
                    title: meta.title,
                    systemImage: meta.systemImage,
                    tint: meta.tint,
                    disabled: busy && !meta.needsSize
                ) {
                    if meta.needsSize {
                        nestedAction = slot
                    } else {
                        perform(slot)
                        finishLog()
                    }
                }
            }

            if let error = connectivity.lastError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            } else if !connectivity.isReachable {
                Text("iPhone unreachable — open the app on your phone.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    @ViewBuilder
    private func nestedPage(for slot: String) -> some View {
        let meta = WatchQuickAddMeta(slot)
        HStack {
            Button {
                nestedAction = nil
            } label: {
                Label("Back", systemImage: "chevron.left")
            }
            .buttonStyle(.bordered)
            Spacer()
        }

        Text(meta.title)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)

        ForEach(snapshot.resolvedHydrationSizes, id: \.self) { oz in
            let label = oz == oz.rounded() ? "\(Int(oz)) oz" : String(format: "%.1f oz", oz)
            actionButton(
                title: "+\(label)",
                systemImage: meta.systemImage,
                tint: meta.tint,
                disabled: busy
            ) {
                connectivity.addHydration(ounces: oz, electrolyte: slot == "electrolyte")
                finishLog()
            }
        }

        if !connectivity.isReachable {
            Text("iPhone unreachable — open the app on your phone.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func finishLog() {
        nestedAction = nil
        onLogged()
    }

    private func perform(_ slot: String) {
        switch slot {
        case "smoking":
            connectivity.addCigarette()
        case "drinking":
            connectivity.addDrink()
        case "bathroomUrine":
            connectivity.addBathroomUrine()
        case "bathroomStool":
            connectivity.addBathroomStool()
        case "electrolyte":
            nestedAction = slot
        default:
            nestedAction = slot
        }
    }

    private func actionButton(
        title: String,
        systemImage: String,
        tint: Color,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .disabled(disabled)
    }
}

private struct WatchQuickAddMeta {
    let title: String
    let systemImage: String
    let tint: Color
    let needsSize: Bool

    init(_ slot: String) {
        switch slot {
        case "electrolyte":
            title = "Electrolytes"
            systemImage = "bolt.fill"
            tint = .yellow
            needsSize = true
        case "smoking":
            title = "Smoking"
            systemImage = "flame.fill"
            tint = .orange
            needsSize = false
        case "drinking":
            title = "Drinking"
            systemImage = "wineglass.fill"
            tint = .purple
            needsSize = false
        case "bathroomUrine":
            title = "Urine"
            systemImage = "drop"
            tint = .blue
            needsSize = false
        case "bathroomStool":
            title = "Stool"
            systemImage = "leaf"
            tint = .brown
            needsSize = false
        default:
            title = "Water"
            systemImage = "drop.fill"
            tint = .cyan
            needsSize = true
        }
    }
}
