import SwiftUI
import WatchConnectivity

@main
struct DailyNutritionTrackerWatchApp: App {
    @StateObject private var connectivity = WatchConnectivityClient.shared

    init() {
        WatchConnectivityClient.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(connectivity)
        }
    }
}

struct WatchRootView: View {
    @EnvironmentObject private var connectivity: WatchConnectivityClient

    var body: some View {
        TabView {
            WatchSummaryView()
            WatchActionsView()
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

    private var snapshot: WatchDaySnapshot { connectivity.snapshot }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("Quick Add")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                actionButton(
                    title: "+\(snapshot.bottleLabel) oz",
                    systemImage: "drop.fill",
                    tint: .cyan,
                    disabled: !connectivity.isReachable || connectivity.isSending
                ) {
                    connectivity.addWater()
                }

                if snapshot.bathroomEnabled {
                    actionButton(
                        title: "Urine",
                        systemImage: "drop",
                        tint: .blue,
                        disabled: !connectivity.isReachable || connectivity.isSending
                    ) {
                        connectivity.addBathroomUrine()
                    }
                    actionButton(
                        title: "Stool",
                        systemImage: "leaf",
                        tint: .brown,
                        disabled: !connectivity.isReachable || connectivity.isSending
                    ) {
                        connectivity.addBathroomStool()
                    }
                }

                if snapshot.smokingEnabled {
                    actionButton(
                        title: "Cigarette",
                        systemImage: "flame.fill",
                        tint: .orange,
                        disabled: !connectivity.isReachable || connectivity.isSending
                    ) {
                        connectivity.addCigarette()
                    }
                }

                if snapshot.drinkingEnabled {
                    actionButton(
                        title: "Drink",
                        systemImage: "wineglass.fill",
                        tint: .purple,
                        disabled: !connectivity.isReachable || connectivity.isSending
                    ) {
                        connectivity.addDrink()
                    }
                }

                if !connectivity.isReachable {
                    Text("iPhone unreachable — open the app on your phone.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 4)
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
