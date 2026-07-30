import Foundation

@MainActor
public struct NavigationTests {
    public static func run() {
        let appState = AppState()
        let initial = appState.currentURL
        let desktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        
        // Positive: Navigation
        appState.navigateTo(desktop)
        TestReporter.report("Navigation", "POS: navigateTo(Desktop)", result: appState.currentURL.standardizedFileURL == desktop.standardizedFileURL)
        
        // Positive: History Back & Forward
        appState.goBack()
        TestReporter.report("Navigation", "POS: goBack() restores previous URL", result: appState.currentURL.standardizedFileURL == initial.standardizedFileURL)
        
        appState.goForward()
        TestReporter.report("Navigation", "POS: goForward() restores forward URL", result: appState.currentURL.standardizedFileURL == desktop.standardizedFileURL)
        
        // Negative: Stack Boundary Checks
        appState.goForward()
        TestReporter.report("Navigation", "NEG: goForward() on empty stack does not crash", result: true)
        
        appState.goBack()
        appState.goBack()
        TestReporter.report("Navigation", "NEG: goBack() on empty stack does not crash", result: true)
        
        // Positive: Favorites Management
        appState.addFavorite(desktop)
        TestReporter.report("Favorites", "POS: addFavorite()", result: appState.isFavorite(desktop))
        
        appState.removeFavorite(desktop)
        TestReporter.report("Favorites", "POS: removeFavorite()", result: !appState.isFavorite(desktop))
    }
}
