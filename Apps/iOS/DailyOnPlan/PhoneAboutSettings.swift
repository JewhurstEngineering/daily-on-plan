import SwiftUI

struct PhoneAboutSettings: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 6) {
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
                LabeledContent("Developer", value: "James Jewhurst")
                LabeledContent("License", value: "MIT")
            }
            Section("What it tracks") {
                Label("Daily plan, protein, and water", systemImage: "checkmark.circle")
                Label("Weight, BMI, and measurements", systemImage: "scalemass")
                Label("Habits, workouts, and supplements", systemImage: "heart.text.square")
            }
            Section {
                Text("Stay on plan. One day at a time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
