@testable import Wiles
import SwiftUI

@MainActor
public struct RenameSheetViewTests {
    public static func run() {
        let appState = AppState()
        let tempURL = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("test_rename.txt")
        let item = FileItem(url: tempURL, icon: NSImage())

        let view = RenameSheetView(item: item, appState: appState)
        report("View/RenameSheetView", "POS: RenameSheetView initializes with item and appState", result: view.item.url.path == item.url.path)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
