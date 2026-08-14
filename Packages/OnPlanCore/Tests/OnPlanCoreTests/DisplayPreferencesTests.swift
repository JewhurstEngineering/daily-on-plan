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
        XCTAssertTrue(decoded.notifyOnThisMac)
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

    func testThemeSwatchHexRoundTrip() {
        let swatch = DisplayPreferences.ThemeSwatch(hex: "#3B82F6")
        XCTAssertEqual(swatch.hexString, "#3B82F6")
    }

    func testMenuBarCompactProtein() {
        var prefs = DisplayPreferences.default
        prefs.menuBarFormat = .compact
        prefs.menuBarLabelStyle = .shortWords
        let snap = ChromeSnapshot.empty
        let title = MenuBarFormatter.title(snapshot: snap, preferences: prefs)
        XCTAssertTrue(title.contains("Protein"))
    }

    func testMenuBarIconsUseSymbols() {
        var prefs = DisplayPreferences.default
        prefs.menuBarFormat = .detailed
        prefs.menuBarLabelStyle = .icons
        let snap = ChromeSnapshot.empty
        let segments = MenuBarFormatter.segments(snapshot: snap, preferences: prefs)
        XCTAssertTrue(segments.contains(where: { $0.systemImage == "fork.knife" }))
        XCTAssertTrue(segments.contains(where: { $0.systemImage == "drop.fill" }))
        XCTAssertFalse(MenuBarFormatter.title(snapshot: snap, preferences: prefs).contains("P "))
    }
}
