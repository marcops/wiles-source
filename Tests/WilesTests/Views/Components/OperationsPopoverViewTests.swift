@testable import Wiles
import SwiftUI

@MainActor
public struct OperationsPopoverViewTests {
    public static func run() {
        let appState = AppState()
        let view = OperationsPopoverView(appState: appState)
        report("View/OperationsPopoverView", "POS: OperationsPopoverView initializes with appState", result: view.service.activeTasks.isEmpty)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
