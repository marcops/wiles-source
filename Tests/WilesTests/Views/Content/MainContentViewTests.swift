import SwiftUI
@testable import Wiles

@MainActor
public struct MainContentViewTests {
    public static func run() {
        let appState = AppState()
        let view = MainContentView(appState: appState)
        report(
            "View/MainContentView",
            "POS: MainContentView initializes with appState",
            result: view.appState.navigation.currentURL.path == appState.navigation.currentURL.path)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
