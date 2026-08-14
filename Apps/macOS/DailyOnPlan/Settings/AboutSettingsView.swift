import SwiftUI
import AppKit
import OnPlanCore

struct AboutSettingsView: View {
    @Environment(\.appTheme) private var theme
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0"
    }

    @State private var installMessage: String?
    @State private var installSucceeded = false
    @State private var aboutSplitHeight: CGFloat = 0
    @State private var titleHeight: CGFloat = 22

    private var isRunningFromApplications: Bool {
        Bundle.main.bundleURL.path.hasPrefix("/Applications/")
    }

    var body: some View {
        MacSettingsScroll {
                hero

                HStack(alignment: .top, spacing: 10) {
                    SettingsPanel(
                        title: "What it tracks",
                        systemImage: "checkmark.seal.fill",
                        subtitle: "Today’s plan, from the menu bar.",
                        compact: true,
                        fillsHeight: true
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            aboutBullet("checkmark.seal", "Followed plan and ketosis")
                            aboutBullet("fork.knife", "Protein calories vs goal")
                            aboutBullet("drop.fill", "Water vs target")
                            aboutBullet("plus.circle", "Quick-add water, cigs, drinks, bathroom")
                        }
                    }
                    .reportMatchedHeight()
                    .frame(maxWidth: .infinity, alignment: .top)
                    .fillMatchedHeight(aboutSplitHeight)

                    SettingsPanel(
                        title: "Desktop widget",
                        systemImage: "rectangle.on.rectangle",
                        subtitle: "Small and medium Daily Status.",
                        compact: true,
                        fillsHeight: true
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Xcode Run copies live in DerivedData, so Edit Widgets search stays empty until the app is installed.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            if isRunningFromApplications {
                                Label("Installed in Applications — search “Daily On Plan”.", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                    .fixedSize(horizontal: false, vertical: true)
                            } else {
                                Button {
                                    do {
                                        let dest = try AppInstall.copyRunningAppToApplications()
                                        installSucceeded = true
                                        installMessage = "Copied to \(dest.path). Keep this Settings window. Then quit the Xcode copy and open the Applications app."
                                    } catch {
                                        installSucceeded = false
                                        installMessage = "Couldn’t install: \(error.localizedDescription)"
                                    }
                                    AppActivation.scheduleSettingsFocus()
                                } label: {
                                    Label("Install to Applications", systemImage: "square.and.arrow.down")
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }

                            if installSucceeded, !isRunningFromApplications {
                                HStack(spacing: 8) {
                                    Button("Reveal in Finder") {
                                        NSWorkspace.shared.activateFileViewerSelecting([AppInstall.installedAppURL])
                                        AppActivation.scheduleSettingsFocus()
                                    }
                                    .controlSize(.small)
                                    Button("Quit this copy & open installed app") {
                                        AppInstall.launchInstalledAndTerminate()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                }
                            }

                            aboutBullet("1.circle", "Install (button above) — does not launch a second copy")
                            aboutBullet("2.circle", "Quit this Xcode build, then open Applications ▸ Daily On Plan")
                            aboutBullet("3.circle", "Right-click desktop → Edit Widgets → Daily On Plan")

                            if let installMessage {
                                Text(installMessage)
                                    .font(.caption2)
                                    .foregroundStyle(installSucceeded ? Color.secondary : Color.orange)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .reportMatchedHeight()
                    .frame(maxWidth: .infinity, alignment: .top)
                    .fillMatchedHeight(aboutSplitHeight)
                }
                .onPreferenceChange(MatchedHeightKey.self) { aboutSplitHeight = $0 }
        }
    }

    private var hero: some View {
        HStack(alignment: .top, spacing: 10) {
            AppLogo(size: titleHeight > 0 ? titleHeight : 22)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 4) {
                Text(AppIdentity.displayName)
                    .font(.title2.weight(.bold))
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: TitleHeightKey.self, value: geo.size.height)
                        }
                    )
                    .onPreferenceChange(TitleHeightKey.self) { titleHeight = $0 }
                Text(AppIdentity.tagline)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Text("v\(version)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(theme.protein.opacity(0.15)))
                        .foregroundStyle(theme.protein)
                    Text("macOS 14+")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(AppAbout.organization)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(AppAbout.copyrightLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("License: \(AppAbout.licenseName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func aboutBullet(_ systemImage: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(theme.tint)
                .frame(width: 16, alignment: .center)
                .padding(.top, 1)
            Text(text)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct TitleHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

