import SwiftUI
@testable import Wiles

@MainActor
public struct EmptyDirectoryViewTests {
    public static func run() {
        let appState = AppState()
        let view = EmptyDirectoryView(appState: appState)
        report("View/EmptyDirectoryView", "POS: EmptyDirectoryView initializes with appState", result: view.appState.searchQuery == "")

        appState.searchQuery = "test"
        let viewWithQuery = EmptyDirectoryView(appState: appState)
        report("View/EmptyDirectoryView", "POS: EmptyDirectoryView reflects active searchQuery", result: viewWithQuery.appState.searchQuery == "test")
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
