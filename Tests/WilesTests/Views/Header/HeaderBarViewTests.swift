@testable import Wiles
import SwiftUI

@MainActor
public struct HeaderBarViewTests {
    public static func run() {
        let appState = AppState()
        let view = HeaderBarView(appState: appState)
        report("View/HeaderBarView", "POS: HeaderBarView initializes with appState", result: view.appState.viewMode == appState.viewMode)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
