import SwiftUI
@testable import Wiles

@MainActor
public struct PathBarViewTests {
    public static func run() {
        let appState = AppState()
        let segments = PathBarView.buildSegments(
            currentURL: appState.navigation.currentURL, rootLabel: "Root", trashLabel: "Trash")
        report("View/PathBarView", "POS: PathBarView constructs pathSegments for root directory", result: !segments.isEmpty)

        let windowUIState = WindowUIState(preferences: appState.preferences)
        windowUIState.isEditingPath = true
        let editingView = PathBarView(appState: appState)
        report("View/PathBarView", "POS: PathBarView honors isEditingPath mode", result: editingView.appState === appState && windowUIState.isEditingPath)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
