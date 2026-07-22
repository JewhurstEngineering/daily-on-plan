import SwiftUI

struct EditTimestampSheet: View {
    let title: String
    let initialDate: Date
    var includesDate: Bool = true
    var onSave: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: Date

    init(
        title: String,
        initialDate: Date,
        includesDate: Bool = true,
        onSave: @escaping (Date) -> Void
    ) {
        self.title = title
        self.initialDate = initialDate
        self.includesDate = includesDate
        self.onSave = onSave
        _draft = State(initialValue: initialDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if includesDate {
                        DatePicker(
                            "Date & time",
                            selection: $draft,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    } else {
                        DatePicker(
                            "Time",
                            selection: $draft,
                            displayedComponents: [.hourAndMinute]
                        )
                    }
                } footer: {
                    if includesDate {
                        Text("Changing the date moves this entry to that day’s log.")
                    } else {
                        Text("Time only — this entry stays on the same day.")
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
