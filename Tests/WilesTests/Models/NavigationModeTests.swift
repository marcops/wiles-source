import Foundation
@testable import Wiles

@MainActor
public struct NavigationModeTests {
    public static func run() {
        testAllCasesAndIdentifiable()
        testL10nKey()
    }

    private static func testAllCasesAndIdentifiable() {
        report(
            "Model/NavigationMode", "POS: NavigationMode has exactly the windows, macOS, and custom cases",
            result: NavigationMode.allCases == [.windows, .macOS, .custom])
        report(
            "Model/NavigationMode",
            "POS: id mirrors rawValue for every case",
            result: NavigationMode.allCases.allSatisfy { $0.id == $0.rawValue })
    }

    private static func testL10nKey() {
        report("Model/NavigationMode", "POS: Windows mode's l10nKey is windowsModeTitle", result: NavigationMode.windows.l10nKey == .windowsModeTitle)
        report("Model/NavigationMode", "POS: macOS mode's l10nKey is macModeTitle", result: NavigationMode.macOS.l10nKey == .macModeTitle)
        report("Model/NavigationMode", "POS: Custom mode's l10nKey is customModeTitle", result: NavigationMode.custom.l10nKey == .customModeTitle)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
