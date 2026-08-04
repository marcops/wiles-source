@testable import Wiles
import Foundation
import CoreGraphics

@MainActor
public struct SelectionStoreTests {
    public static func run() {
        let store = SelectionStore()
        report("Store/SelectionStore", "POS: gridCellFrames starts empty", result: store.gridCellFrames.isEmpty)
        report("Store/SelectionStore", "POS: gridColumnCount default is 1 when empty", result: store.gridColumnCount == 1)

        store.columnViewDrillRightTrigger += 1
        report("Store/SelectionStore", "POS: columnViewDrillRightTrigger increments", result: store.columnViewDrillRightTrigger == 1)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
