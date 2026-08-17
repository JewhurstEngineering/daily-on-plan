import Foundation

enum AppAbout {
    static let copyrightHolder = "jamesware.dev"
    static let organization = "Made with care by JamesWare.dev"
    static var copyrightYear: String {
        String(Calendar.current.component(.year, from: Date()))
    }
    static let licenseName = "MIT"

    static var copyrightLine: String {
        "Copyright © \(copyrightYear) \(copyrightHolder)"
    }
}
