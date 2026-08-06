import Foundation

enum AppDeepLink {
    static let scheme = "dailyonplan"

    static func sectionURL(_ section: DaySectionID) -> URL {
        URL(string: "\(scheme)://day?section=\(section.rawValue)")!
    }

    static func section(from url: URL) -> String? {
        guard url.scheme == scheme else { return nil }
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let section = components.queryItems?.first(where: { $0.name == "section" })?.value,
           !section.isEmpty {
            return section
        }
        // dailyonplan://hydration
        let host = url.host?.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if let host, DaySectionID(rawValue: host) != nil {
            return host
        }
        return nil
    }
}
