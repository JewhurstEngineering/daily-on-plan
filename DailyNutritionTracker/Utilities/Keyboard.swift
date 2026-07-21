import SwiftUI
import UIKit

enum Keyboard {
    static func dismiss() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

extension View {
    /// Adds a Done button above the keyboard (needed for decimal/number pads).
    func keyboardDoneToolbar(focus: FocusState<Bool>.Binding) -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focus.wrappedValue = false
                    Keyboard.dismiss()
                }
            }
        }
    }
}
