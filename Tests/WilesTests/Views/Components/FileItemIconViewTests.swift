import SwiftUI
@testable import Wiles

@MainActor
public struct FileItemIconViewTests {
    public static func run() {
        let tempURL = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("test_icon.txt")
        let item = FileItem(url: tempURL, icon: NSImage())

        let view = FileItemIconView(item: item, size: 32)
        report("View/FileItemIconView", "POS: FileItemIconView initializes with size 32", result: view.size == 32)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
