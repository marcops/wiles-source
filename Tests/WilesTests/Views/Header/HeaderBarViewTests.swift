import SwiftUI
@testable import Wiles

@MainActor
public struct HeaderBarViewTests {
    public static func run() {
        let appState = AppState()
        let view = HeaderBarView(appState: appState)
        report(
            "View/HeaderBarView",
            "POS: HeaderBarView initializes with appState",
            result: view.appState.preferences.view.viewMode == appState.preferences.view.viewMode)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
