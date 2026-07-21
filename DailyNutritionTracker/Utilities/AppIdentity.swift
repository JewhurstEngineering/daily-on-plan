import Foundation

/// Single source for the user-facing app name.
/// Change `PRODUCT_DISPLAY_NAME` in Info.plist / Xcode build settings — Swift reads it from the bundle.
enum AppIdentity {
    static var displayName: String {
        if let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !name.isEmpty {
            return name
        }
        if let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String,
           !name.isEmpty {
            return name
        }
        return "Daily On Plan"
    }

    static let tagline = "Stay on plan. One day at a time."
}
