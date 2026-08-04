@testable import Wiles
import SwiftUI

@MainActor
public struct FooterBarViewTests {
    public static func run() {
        let appState = AppState()
        let view = FooterBarView(appState: appState)
        report("View/FooterBarView", "POS: FooterBarView statusText matches appState", result: view.appState.statusText == appState.statusText)

        let initialDrawer = appState.showTerminalDrawer
        defer { appState.showTerminalDrawer = initialDrawer }

        appState.showTerminalDrawer.toggle()
        report("View/FooterBarView", "POS: FooterBarView terminal drawer toggling works", result: appState.showTerminalDrawer != initialDrawer)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
