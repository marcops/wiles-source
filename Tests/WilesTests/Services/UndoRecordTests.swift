import Foundation
@testable import Wiles

@MainActor
public struct UndoRecordTests {
    public static func run() {
        testInitStoresActionTypeAndGeneratesFreshIdAndTimestamp()
        testEachRecordGetsAUniqueId()
    }

    private static func testInitStoresActionTypeAndGeneratesFreshIdAndTimestamp() {
        let url = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("created_\(UUID().uuidString).txt")
        let before = Date()
        let record = UndoRecord(actionType: .createFolder(url: url))
        let after = Date()

        if case let .createFolder(storedURL) = record.actionType {
            report("Services/UndoRecord", "POS: init stores the actionType passed to it", result: storedURL == url)
        } else {
            report("Services/UndoRecord", "POS: init stores the actionType passed to it", result: false)
        }

        report(
            "Services/UndoRecord",
            "POS: timestamp is set to the moment of construction, between before/after bounds",
            result: record.timestamp >= before && record.timestamp <= after)
    }

    private static func testEachRecordGetsAUniqueId() {
        let url = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("dup_\(UUID().uuidString).txt")
        let recordA = UndoRecord(actionType: .createFolder(url: url))
        let recordB = UndoRecord(actionType: .createFolder(url: url))
        report("Services/UndoRecord", "NEG: two UndoRecords with the same actionType still get distinct ids", result: recordA.id != recordB.id)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
