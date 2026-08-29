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

        var handlerCalls = 0
        store.setSearchQueryHandler { handlerCalls += 1 }
        store.searchQuery = "typed"
        report("Store/SelectionStore", "POS: a normal searchQuery assignment fires the change handler", result: handlerCalls == 1)
        store.setSearchQuerySilently("smart folder query")
        report(
            "Store/SelectionStore",
            "NEG: setSearchQuerySilently updates the value but does not fire the change handler",
            result: store.searchQuery == "smart folder query" && handlerCalls == 1)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
