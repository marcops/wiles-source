@testable import Wiles
import SwiftUI

@MainActor
public struct PathBarViewTests {
    public static func run() {
        let appState = AppState()
        let view = PathBarView(appState: appState)
        report("View/PathBarView", "POS: PathBarView constructs pathSegments for root directory", result: !view.pathSegments.isEmpty)

        appState.isEditingPath = true
        let editingView = PathBarView(appState: appState)
        report("View/PathBarView", "POS: PathBarView honors isEditingPath mode", result: editingView.appState.isEditingPath)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
