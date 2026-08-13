import SwiftUI
#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Color logo (light/dark variants) or the menu-bar template silhouette.
struct AppLogo: View {
    var size: CGFloat = 34
    var template: Bool = false
    /// Square logo that matches the height of neighboring content.
    var fillHeight: Bool = false

    private var assetName: String { template ? "AppLogoTemplate" : "AppLogo" }

    private var assetExists: Bool {
        #if os(macOS)
        NSImage(named: assetName) != nil
        #elseif canImport(UIKit)
        UIImage(named: assetName) != nil
        #else
        false
        #endif
    }

    var body: some View {
        let image = Group {
            if assetExists {
                Image(assetName)
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
        .accessibilityHidden(true)

        if fillHeight {
            image
                .frame(maxHeight: .infinity)
                .aspectRatio(1, contentMode: .fit)
        } else {
            image
                .frame(width: size, height: size)
        }
    }
}
