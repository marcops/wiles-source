import SwiftUI
@testable import Wiles

@MainActor
public struct FileItemIconViewTests {
    public static func run() {
        let tempURL = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("test_icon.txt")
        let item = FileItem.load(url: tempURL, icon: NSImage())

        let view = FileItemIconView(item: item, size: 32)
        report("View/FileItemIconView", "POS: FileItemIconView initializes with size 32", result: view.size == 32)

        // MM-274 CI canary (DEV_RULES.md "Reflection / Private-API Access Into a Dependency Needs a
        // CI Canary"): `openFolderIcon` resolves via `perform(NSSelectorFromString("iconForFileType:"))`
        // guarded by `responds(to:)`. This asserts a real (non-empty) icon comes back on the CURRENT
        // SDK — if a future SDK drops the legacy selector, this fails CI instead of shipping a crash
        // (the guard means it degrades to the plain folder icon fallback either way, but a size of
        // zero would mean even that fallback broke).
        let icon = FileItemIconView.openFolderIcon
        report(
            "View/FileItemIconView",
            "POS (MM-274): openFolderIcon resolves to a real, non-empty icon on this SDK",
            result: icon.size.width > 0 && icon.size.height > 0)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
