@testable import Wiles
import SwiftUI

@MainActor
public struct ShortcutsHUDOverlayTests {
    public static func run() {
        let appState = AppState()
        let view = ShortcutsHUDOverlay(appState: appState)
        report("View/ShortcutsHUDOverlay", "POS: ShortcutsHUDOverlay initializes with appState", result: view.appState.showShortcutsHUD == appState.showShortcutsHUD)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
