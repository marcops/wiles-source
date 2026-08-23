import Foundation
@testable import Wiles

@MainActor
public struct NavigationModeTests {
    public static func run() {
        testAllCasesAndIdentifiable()
        testL10nKey()
    }

    private static func testAllCasesAndIdentifiable() {
        report("Model/NavigationMode", "POS: NavigationMode has exactly the gnome and macOS cases", result: NavigationMode.allCases == [.gnome, .macOS])
        report(
            "Model/NavigationMode",
            "POS: id mirrors rawValue for every case",
            result: NavigationMode.allCases.allSatisfy { $0.id == $0.rawValue })
    }

    private static func testL10nKey() {
        report("Model/NavigationMode", "POS: gnome mode's l10nKey is gnomeModeTitle", result: NavigationMode.gnome.l10nKey == .gnomeModeTitle)
        report("Model/NavigationMode", "POS: macOS mode's l10nKey is macModeTitle", result: NavigationMode.macOS.l10nKey == .macModeTitle)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
