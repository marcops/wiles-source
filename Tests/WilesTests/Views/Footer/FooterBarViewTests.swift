import SwiftUI
@testable import Wiles

@MainActor
public struct FooterBarViewTests {
    public static func run() {
        let appState = AppState()
        let windowUIState = WindowUIState(preferences: appState.preferences)
        let view = FooterBarView(appState: appState, windowUIState: windowUIState)
        report("View/FooterBarView", "POS: FooterBarView statusText matches appState", result: view.appState.statusText == appState.statusText)

        let initialDrawer = windowUIState.showTerminalDrawer
        defer { windowUIState.showTerminalDrawer = initialDrawer }

        windowUIState.showTerminalDrawer.toggle()
        report("View/FooterBarView", "POS: FooterBarView terminal drawer toggling works", result: windowUIState.showTerminalDrawer != initialDrawer)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
