@testable import Wiles
import SwiftUI

@MainActor
public struct FileContextMenuModifierTests {
    public static func run() {
        let appState = AppState()
        let tempURL = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("test_ctx.txt")
        let item = FileItem(url: tempURL, icon: NSImage())

        let modifier = FileContextMenuModifier(item: item, appState: appState)
        report("View/FileContextMenuModifier", "POS: FileContextMenuModifier initializes with item and appState", result: modifier.item.url.path == item.url.path)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
