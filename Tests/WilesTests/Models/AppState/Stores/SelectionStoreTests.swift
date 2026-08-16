import CoreGraphics
import Foundation
@testable import Wiles

@MainActor
public struct SelectionStoreTests {
    public static func run() {
        let store = SelectionStore()
        report("Store/SelectionStore", "POS: gridCellFrames starts empty", result: store.gridCellFrames.isEmpty)
        report("Store/SelectionStore", "POS: gridColumnCount default is 1 when empty", result: store.gridColumnCount == 1)

        report("Store/SelectionStore", "POS: gridLabelWidths starts empty", result: store.gridLabelWidths.isEmpty)
        let url = URL(fileURLWithPath: "/tmp/wiles-selection-store-test-item")
        store.gridLabelWidths[url] = 42.0
        report("Store/SelectionStore", "POS: gridLabelWidths holds the value it was set to", result: store.gridLabelWidths[url] == 42.0)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
