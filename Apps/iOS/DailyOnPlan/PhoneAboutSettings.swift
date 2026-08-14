import SwiftUI

struct PhoneAboutSettings: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    AppLogo(size: 64)
                    Text(AppIdentity.displayName)
                        .font(.title2.weight(.semibold))
                    Text(AppIdentity.tagline)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
                LabeledContent("Version", value: version)
                LabeledContent("Developer", value: AppAbout.organization)
                LabeledContent("License", value: AppAbout.licenseName)
            }
            Section("What it tracks") {
                Label("Daily plan, protein, and water", systemImage: "checkmark.circle")
                Label("Weight, BMI, and measurements", systemImage: "scalemass")
                Label("Habits, workouts, and supplements", systemImage: "heart.text.square")
            }
            Section {
                Text(AppAbout.copyrightLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Stay on plan. One day at a time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
