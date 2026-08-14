import SwiftUI
import SwiftData
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

struct BackupRestoreView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var onRestored: ((AppSettings) -> Void)?

    @State private var isWorking = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var shareItem: ShareableBackup?
    @State private var showImporter = false
    @State private var pendingSnapshot: BackupSnapshot?
    @State private var showReplaceConfirm = false

    var body: some View {
        Form {
            Section {
                Button {
                    createBackup()
                } label: {
                    Label("Create backup", systemImage: "square.and.arrow.up")
                }
                .disabled(isWorking)

                Button(role: .destructive) {
                    showImporter = true
                } label: {
                    Label("Restore from backup…", systemImage: "square.and.arrow.down")
                }
                .disabled(isWorking)
            } footer: {
                Text("Backups include all days, weights, measurements, presets, meals, and settings. USDA API keys stay on this device and are not included. Restore replaces everything currently in the app. Use Backup before deleting the app — Export reports cannot restore data.")
            }

            if isWorking {
                Section {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Working…")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let statusMessage {
                Section {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Backup & restore")
        .onPlanInlineNav()
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
        #if os(iOS)
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
        #elseif os(macOS)
        .onChange(of: shareItem) { _, item in
            guard let url = item?.url else { return }
            NSWorkspace.shared.activateFileViewerSelecting([url])
            shareItem = nil
        }
        #endif
    }

    private static var allowedTypes: [UTType] {
        var types: [UTType] = [.json, .data]
        if let custom = UTType(filenameExtension: BackupService.fileExtension) {
            types.insert(custom, at: 0)
        }
        return types
    }

    private func createBackup() {
        isWorking = true
        statusMessage = nil
        errorMessage = nil
        Task { @MainActor in
            do {
                let url = try BackupService.createBackup(from: modelContext)
                isWorking = false
                statusMessage = "Ready: \(url.lastPathComponent)"
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    shareItem = ShareableBackup(url: url)
                }
            } catch {
                isWorking = false
                errorMessage = error.localizedDescription
            }
        }
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
        statusMessage = nil
        errorMessage = nil
        pendingSnapshot = nil
        Task { @MainActor in
            do {
                let settings = try BackupService.replaceAll(with: snapshot, in: modelContext)
                onRestored?(settings)
                NotificationCenter.default.post(name: .onPlanJournalDidChange, object: nil)
                isWorking = false
                statusMessage = "Restored \(BackupService.summary(for: snapshot))."
            } catch {
                isWorking = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct ShareableBackup: Identifiable, Equatable {
    let id = UUID()
    let url: URL
}
