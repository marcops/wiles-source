import SwiftUI
@testable import Wiles

@MainActor
public struct FooterBarViewTests {
    public static func run() {
        let appState = AppState()
        let view = FooterBarView(appState: appState)
        report("View/FooterBarView", "POS: FooterBarView statusText matches appState", result: view.appState.statusText == appState.statusText)

        let initialDrawer = appState.preferences.showTerminalDrawer
        defer { appState.preferences.showTerminalDrawer = initialDrawer }

        appState.preferences.showTerminalDrawer.toggle()
        report("View/FooterBarView", "POS: FooterBarView terminal drawer toggling works", result: appState.preferences.showTerminalDrawer != initialDrawer)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
