import SwiftUI

struct SettingsOpenLink<Label: View>: View {
    @ViewBuilder var label: () -> Label

    var body: some View {
        SettingsLink(label: label)
            .simultaneousGesture(
                TapGesture().onEnded {
                    AppActivation.scheduleSettingsFocus()
                }
            )
    }
}
