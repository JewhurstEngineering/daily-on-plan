import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct FirstLaunchImportView: View {
    static let didOfferKey = "dop.didOfferFirstLaunchImport"

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var healthKit: HealthKitService

    @State private var step: Step = .backup
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var showImporter = false
    @State private var pendingSnapshot: BackupSnapshot?
    @State private var showReplaceConfirm = false

    @State private var phase: ProgramPhase = .week1
    @State private var usesMetric = false
    @State private var proteinGoal = 500
    @State private var waterTarget = AppLimits.hydrationTargetOz

    private enum Step {
        case backup
        case setup
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .backup:
                    backupPage
                case .setup:
                    setupPage
                }
            }
            .padding(24)
            .onPlanInlineNav()
        }
        .interactiveDismissDisabled()
        .disabled(isWorking)
        .alert("Restore failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .confirmationDialog(
            "Replace all data?",
            isPresented: $showReplaceConfirm,
            titleVisibility: .visible
        ) {
            Button("Replace all data", role: .destructive) {
                if let pendingSnapshot {
                    performRestore(pendingSnapshot)
                }
            }
            Button("Cancel", role: .cancel) {
                pendingSnapshot = nil
            }
        } message: {
            if let pendingSnapshot {
                Text("This permanently replaces all local data with the backup (\(BackupService.summary(for: pendingSnapshot))). This cannot be undone.")
            } else {
                Text("This permanently replaces all local data with the backup.")
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: Self.allowedTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                loadPendingBackup(from: url)
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }

    private var backupPage: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 12)

            Image(systemName: "externaldrive.badge.icloud")
                .font(.system(size: 44))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)

            VStack(spacing: 10) {
                Text("Have a Daily On Plan backup?")
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text("Restore it to bring days, weights, and settings onto this phone. You can also do this later in Settings → Backup.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer(minLength: 12)

            VStack(spacing: 12) {
                Button {
                    showImporter = true
                } label: {
                    Text("Restore from backup…")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isWorking)

                Button {
                    step = .setup
                } label: {
                    Text("Start fresh")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(isWorking)
            }

            if isWorking {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Restoring…")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
        }
    }

    private var setupPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Set up your sheet")
                    .font(.title2.weight(.semibold))
                Text("Week 1 is protein, veggies, and misc only. Week 2 & Beyond unlocks fats and fruits. You can change this later in Settings.")
                    .font(.body)
                    .foregroundStyle(.secondary)

                Picker("Program phase", selection: $phase) {
                    ForEach(ProgramPhase.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Metric weight (kg)", isOn: $usesMetric)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Protein goal: \(proteinGoal) kcal")
                        .font(.subheadline.weight(.medium))
                    Stepper(value: $proteinGoal, in: AppLimits.proteinGoalMin...AppLimits.proteinGoalMax, step: 25) {
                        Text("Daily protein calories")
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Hydration target: \(waterTarget) oz")
                        .font(.subheadline.weight(.medium))
                    Stepper(value: $waterTarget, in: 16...200, step: 8) {
                        Text("Daily water")
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    Task { await healthKit.requestAuthorization() }
                } label: {
                    Label(
                        healthKit.isAuthorized ? "Apple Health connected" : "Connect Apple Health",
                        systemImage: healthKit.isAuthorized ? "checkmark.circle.fill" : "heart.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(healthKit.isAuthorized)

                Text("Ketosis and Followed plan start off each new day until you log them. The app does not measure ketones.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    saveSetupAndFinish()
                } label: {
                    Text("Start logging")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    private static var allowedTypes: [UTType] {
        var types: [UTType] = [.json, .data]
        if let custom = UTType(filenameExtension: BackupService.fileExtension) {
            types.insert(custom, at: 0)
        }
        return types
    }

    private func markOffered() {
        UserDefaults.standard.set(true, forKey: Self.didOfferKey)
    }

    private func saveSetupAndFinish() {
        let settings = DataStore.settings(in: modelContext)
        settings.phase = phase
        settings.usesMetricWeight = usesMetric
        settings.defaultProteinGoal = proteinGoal
        settings.hydrationTargetOz = waterTarget
        try? modelContext.save()
        markOffered()
        dismiss()
    }

    private func loadPendingBackup(from url: URL) {
        do {
            let snapshot = try BackupService.loadSnapshot(from: url)
            pendingSnapshot = snapshot
            showReplaceConfirm = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func performRestore(_ snapshot: BackupSnapshot) {
        isWorking = true
        errorMessage = nil
        pendingSnapshot = nil
        Task { @MainActor in
            do {
                _ = try BackupService.replaceAll(with: snapshot, in: modelContext)
                isWorking = false
                markOffered()
                dismiss()
            } catch {
                isWorking = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
