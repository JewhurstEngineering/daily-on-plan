import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct FirstLaunchImportView: View {
    static let didOfferKey = "dop.didOfferFirstLaunchImport"

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var showImporter = false
    @State private var pendingSnapshot: BackupSnapshot?
    @State private var showReplaceConfirm = false

    var body: some View {
        NavigationStack {
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
                        markOffered()
                        dismiss()
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
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
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
