import SwiftUI
#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Branded On Plan icon. Uses the `AppLogo` asset, then the compiled app icon.
struct AppLogo: View {
    var size: CGFloat = 34
    var template: Bool = false

    var body: some View {
        artwork
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var artwork: some View {
        if template, hasImage("AppLogoTemplate") {
            Image("AppLogoTemplate")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
        } else if hasImage("AppLogo") {
            Image("AppLogo")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
        } else if let icon = platformAppIcon {
            icon
                .resizable()
                .interpolation(.high)
                .scaledToFit()
        } else {
            Image(systemName: "checkmark.seal.fill")
                .resizable()
                .scaledToFit()
                .symbolRenderingMode(.hierarchical)
        }
    }

    private func hasImage(_ name: String) -> Bool {
        #if os(macOS)
        NSImage(named: name) != nil
        #elseif canImport(UIKit)
        UIImage(named: name) != nil
        #else
        false
        #endif
    }

    private var platformAppIcon: Image? {
        #if os(macOS)
        if let icon = NSApp.applicationIconImage {
            return Image(nsImage: icon)
        }
        #endif
        return nil
    }
}
