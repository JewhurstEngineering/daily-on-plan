import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum Keyboard {
    static func dismiss() {
        #if os(iOS)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
        #elseif os(macOS)
        NSApp.keyWindow?.makeFirstResponder(nil)
        #endif
    }
}

extension View {
    /// Adds a Done button above the keyboard (needed for decimal/number pads).
    @ViewBuilder
    func keyboardDoneToolbar(focus: FocusState<Bool>.Binding) -> some View {
        #if os(iOS)
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focus.wrappedValue = false
                    Keyboard.dismiss()
                }
            }
        }
        #else
        self
        #endif
    }
}
