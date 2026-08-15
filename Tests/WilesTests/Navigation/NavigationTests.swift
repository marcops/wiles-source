import Foundation
@testable import Wiles

@MainActor
public struct NavigationTests {
    public static func run() {
        let appState = AppState()
        let initial = appState.navigation.currentURL
        let tempTarget = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("NavTestFolder_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempTarget, withIntermediateDirectories: true)

        // Positive: Navigation
        appState.navigateTo(tempTarget)
        TestReporter.report(
            "Navigation",
            "POS: navigateTo(tempTarget)",
            result: appState.navigation.currentURL.standardizedFileURL == tempTarget.standardizedFileURL)

        // Positive: History Back & Forward
        appState.goBack()
        TestReporter.report(
            "Navigation",
            "POS: goBack() restores previous URL",
            result: appState.navigation.currentURL.standardizedFileURL == initial.standardizedFileURL)

        appState.goForward()
        TestReporter.report(
            "Navigation",
            "POS: goForward() restores forward URL",
            result: appState.navigation.currentURL.standardizedFileURL == tempTarget.standardizedFileURL)

        // Negative: Stack Boundary Checks
        appState.goForward()
        TestReporter.report("Navigation", "NEG: goForward() on empty stack does not crash", result: true)

        appState.goBack()
        appState.goBack()
        TestReporter.report("Navigation", "NEG: goBack() on empty stack does not crash", result: true)

        // Positive: Favorites Management
        appState.addFavorite(tempTarget)
        TestReporter.report("Favorites", "POS: addFavorite()", result: appState.isFavorite(tempTarget))

        appState.removeFavorite(tempTarget)
        TestReporter.report("Favorites", "POS: removeFavorite()", result: !appState.isFavorite(tempTarget))
    }
}
