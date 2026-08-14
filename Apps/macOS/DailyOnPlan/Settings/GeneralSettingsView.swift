import SwiftUI
import OnPlanCore
import ServiceManagement
import UserNotifications

struct GeneralSettingsView: View {
    @EnvironmentObject private var store: OnPlanStore
    @State private var statusTick = 0
    @State private var isChecking = false
    @State private var authStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        MacSettingsFillStack {
            MacSettingsTwoColumn {
                thisMacPanel
            } right: {
                todayPanel
            }
            MacSettingsTwoColumn {
                iCloudPanel
            } right: {
                remindersPanel
            }
        }
        .task { await refreshPermission() }
    }

    private var thisMacPanel: some View {
        SettingsPanel(
            title: "This Mac",
            systemImage: "laptopcomputer",
            subtitle: "Lives in the menu bar. Click the icon for today’s log.",
            fillsHeight: true
        ) {
            Toggle("Launch at login", isOn: launchAtLoginBinding)
                .toggleStyle(.checkbox)

            Toggle("Show metrics next to the icon", isOn: showMenuBarBinding)
                .toggleStyle(.checkbox)

            Text("Density, labels, and which metrics appear are in Layout.")
                .appFont(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            MenuBarPreviewStrip(
                snapshot: store.snapshot.forSettingsPreview,
                preferences: store.preferences
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var todayPanel: some View {
        let snap = store.snapshot
        return SettingsPanel(
            title: "Today",
            systemImage: "sun.max",
            subtitle: snap.generatedAt == .distantPast
                ? "Waiting on the iCloud journal."
                : "Live from this Mac’s copy of the journal.",
            fillsHeight: true
        ) {
            metricRow(
                "Protein",
                value: "\(snap.proteinCalories) / \(snap.proteinGoal) kcal",
                fraction: snap.proteinFraction
            )
            metricRow(
                "Water",
                value: "\(snap.waterOz) / \(snap.waterTargetOz) oz",
                fraction: snap.waterFraction
            )
            HStack(spacing: 16) {
                statusChip("Plan", on: snap.followedPlan)
                statusChip("Ketosis", on: snap.ketosis)
            }
            if snap.fastingEnabled, !snap.fastingStatusLine.isEmpty {
                Text(snap.fastingStatusLine)
                    .appFont(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var iCloudPanel: some View {
        SettingsPanel(
            title: "iCloud",
            systemImage: "icloud",
            subtitle: "Journal syncs with iPhone. Theme and menu bar stay here.",
            fillsHeight: true
        ) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Circle()
                    .fill(SharedModelContainer.usesCloudKit ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(iCloudLine)
                    .appFont(.subheadline, weight: .semibold)
                    .id(statusTick)
                Spacer(minLength: 8)
                Button {
                    isChecking = true
                    defer { isChecking = false }
                    _ = try? SharedModelContainer.reopen()
                    MacDaySync.refresh(store: store)
                    statusTick += 1
                } label: {
                    if isChecking {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Check now")
                    }
                }
                .controlSize(.small)
                .disabled(isChecking)
            }
            Text("Full backup and restore live in Data.")
                .appFont(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var remindersPanel: some View {
        SettingsPanel(
            title: "Reminders on this Mac",
            systemImage: "bell",
            subtitle: "Times live in Notifications. This mute is Mac-only.",
            fillsHeight: true
        ) {
            Toggle("Show banners on this Mac", isOn: Binding(
                get: { store.preferences.notifyOnThisMac },
                set: { value in
                    var prefs = store.preferences
                    prefs.notifyOnThisMac = value
                    store.applyPreferences(prefs)
                    MacNotifications.sync(requestIfNeeded: value)
                    Task { await refreshPermission() }
                }
            ))
            .toggleStyle(.checkbox)

            Text(permissionCopy)
                .appFont(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if authStatus == .denied {
                Button("Open System Settings") {
                    MacNotifications.openSystemSettings()
                }
                .controlSize(.small)
            } else if authStatus == .notDetermined, store.preferences.notifyOnThisMac {
                Button("Allow notifications") {
                    Task {
                        _ = await NotificationService.shared.requestPermission()
                        await refreshPermission()
                        await MacNotifications.syncNow(requestIfNeeded: false)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func metricRow(_ title: String, value: String, fraction: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .appFont(.subheadline, weight: .semibold)
                Spacer()
                Text(value)
                    .appFont(.caption, mono: true)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: min(max(fraction, 0), 1))
        }
    }

    private func statusChip(_ title: String, on: Bool) -> some View {
        Label(on ? "\(title) yes" : "\(title) no", systemImage: on ? "checkmark.circle.fill" : "circle")
            .appFont(.caption)
            .foregroundStyle(on ? .green : .secondary)
    }

    private var iCloudLine: String {
        if SharedModelContainer.usesCloudKit {
            return "iCloud on"
        }
        if let error = SharedModelContainer.cloudKitError {
            return "iCloud off — \(error)"
        }
        return "iCloud off"
    }

    private var permissionCopy: String {
        switch authStatus {
        case .authorized, .provisional:
            return store.preferences.notifyOnThisMac
                ? "This Mac will show the reminders that are on."
                : "Off here. iPhone is unchanged."
        case .denied:
            return "macOS has notifications off for Daily On Plan."
        default:
            return "Allow once so this Mac can remind you."
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { store.preferences.launchAtLogin },
            set: { newValue in
                var prefs = store.preferences
                prefs.launchAtLogin = newValue
                store.applyPreferences(prefs)
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {}
            }
        )
    }

    private var showMenuBarBinding: Binding<Bool> {
        Binding(
            get: { store.preferences.showInMenuBar },
            set: { value in
                var prefs = store.preferences
                prefs.showInMenuBar = value
                store.applyPreferences(prefs)
            }
        )
    }

    private func refreshPermission() async {
        authStatus = await NotificationService.shared.authorizationStatus()
    }
}
