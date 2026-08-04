@testable import Wiles
import SwiftUI

@MainActor
public struct MainContentViewTests {
    public static func run() {
        let appState = AppState()
        let view = MainContentView(appState: appState)
        report("View/MainContentView", "POS: MainContentView initializes with appState", result: view.appState.currentURL.path == appState.currentURL.path)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
