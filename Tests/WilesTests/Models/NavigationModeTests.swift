import Foundation
@testable import Wiles

@MainActor
public struct NavigationModeTests {
    public static func run() {
        testAllCasesAndIdentifiable()
        testL10nKey()
    }

    private static func testAllCasesAndIdentifiable() {
        report("Model/NavigationMode", "POS: NavigationMode has exactly the windows and macOS cases", result: NavigationMode.allCases == [.windows, .macOS])
        report(
            "Model/NavigationMode",
            "POS: id mirrors rawValue for every case",
            result: NavigationMode.allCases.allSatisfy { $0.id == $0.rawValue })
    }

    private static func testL10nKey() {
        report("Model/NavigationMode", "POS: Windows mode's l10nKey is windowsModeTitle", result: NavigationMode.windows.l10nKey == .windowsModeTitle)
        report("Model/NavigationMode", "POS: macOS mode's l10nKey is macModeTitle", result: NavigationMode.macOS.l10nKey == .macModeTitle)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
