import SwiftUI
import SwiftData

enum OnPlanKeyboard {
    case `default`
    case decimalPad
    case numberPad
}

extension Color {
    static var onPlanSecondaryFill: Color {
        #if os(iOS)
        Color(.secondarySystemBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }

    static var onPlanTertiaryFill: Color {
        #if os(iOS)
        Color(.tertiarySystemFill)
        #else
        Color(nsColor: .tertiarySystemFill)
        #endif
    }
}

extension View {
    @ViewBuilder
    func onPlanInlineNav() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    @ViewBuilder
    func onPlanKeyboard(_ kind: OnPlanKeyboard) -> some View {
        #if os(iOS)
        switch kind {
        case .default: keyboardType(.default)
        case .decimalPad: keyboardType(.decimalPad)
        case .numberPad: keyboardType(.numberPad)
        }
        #else
        self
        #endif
    }

    @ViewBuilder
    func onPlanNeverAutocapitalize() -> some View {
        #if os(iOS)
        textInputAutocapitalization(.never)
        #else
        self
        #endif
    }

    @ViewBuilder
    func onPlanKeyboardDone(_ action: @escaping () -> Void) -> some View {
        #if os(iOS)
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { action() }
            }
        }
        #else
        self
        #endif
    }
}

extension ModelContext {
    func saveAndNotifyJournal() {
        try? save()
        NotificationCenter.default.post(name: .onPlanJournalDidChange, object: nil)
    }
}
