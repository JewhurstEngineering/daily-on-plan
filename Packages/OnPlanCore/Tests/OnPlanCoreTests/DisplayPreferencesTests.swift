import XCTest
@testable import OnPlanCore

final class DisplayPreferencesTests: XCTestCase {
    func testRoundTripDefaults() throws {
        let data = try JSONEncoder().encode(DisplayPreferences.default)
        let decoded = try JSONDecoder().decode(DisplayPreferences.self, from: data)
        XCTAssertEqual(decoded, .default)
    }

    func testUnknownKeysUseDefaults() throws {
        let json = Data("{}".utf8)
        let decoded = try JSONDecoder().decode(DisplayPreferences.self, from: json)
        XCTAssertEqual(decoded.colorTheme, .onPlan)
        XCTAssertTrue(decoded.menuBar.protein)
        XCTAssertTrue(decoded.popover.bathroom)
        XCTAssertEqual(decoded.watchQuickAdd.resolvedSlots, [.water, .electrolyte, .smoking])
    }

    func testWatchQuickAddRoundTrip() throws {
        var prefs = DisplayPreferences.default
        prefs.watchQuickAdd.slots = [.water, .electrolyte, .smoking]
        prefs.watchQuickAdd.hydrationSizesOz = [8, 16.9, 24]
        let data = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(DisplayPreferences.self, from: data)
        XCTAssertEqual(decoded.watchQuickAdd.resolvedSlots, [.water, .electrolyte, .smoking])
        XCTAssertEqual(decoded.watchQuickAdd.hydrationSizesOz, [8, 16.9, 24])
    }

    func testMenuBarCompactProtein() {
        var prefs = DisplayPreferences.default
        prefs.menuBarFormat = .compact
        prefs.menuBarLabelStyle = .shortWords
        let snap = ChromeSnapshot.empty
        let title = MenuBarFormatter.title(snapshot: snap, preferences: prefs)
        XCTAssertTrue(title.contains("Protein"))
    }
}
