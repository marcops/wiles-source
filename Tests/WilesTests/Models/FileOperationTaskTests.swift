import Foundation
@testable import Wiles

@MainActor
public struct FileOperationTaskTests {
    public static func run() {
        let task = FileOperationTask(
            title: "Copying files",
            unitsDone: 500,
            unitsTotal: 1000)
        report("Model/FileOperationTask", "POS: Task title matches input", result: task.title == "Copying files")
        report("Model/FileOperationTask", "POS: Task progress derives from unitsDone/unitsTotal", result: task.progress == 0.5)

        testInitDefaults()
        testProgressWhenUnitsTotalIsZero()
        testProgressWhenUnitsDoneExceedsUnitsTotal()
    }

    /// `init` defaults both counters to 0 (M14 renamed `bytesTransferred`/`totalBytes`).
    private static func testInitDefaults() {
        let task = FileOperationTask(title: "Pending")
        report(
            "Model/FileOperationTask",
            "POS: unitsDone and unitsTotal default to 0",
            result: task.unitsDone == 0 && task.unitsTotal == 0)
    }

    /// `progress`'s `unitsTotal > 0 ? ... : 0` guard: a task with no total reports 0, never NaN,
    /// even once units have been done against it.
    private static func testProgressWhenUnitsTotalIsZero() {
        var task = FileOperationTask(title: "Indeterminate", unitsDone: 0, unitsTotal: 0)
        report("Model/FileOperationTask", "POS: progress is 0 when unitsTotal is 0", result: task.progress == 0)

        task.unitsDone = 42
        report(
            "Model/FileOperationTask",
            "NEG: progress stays 0 (not NaN/inf) when unitsDone is advanced but unitsTotal is still 0",
            result: task.progress == 0)
    }

    /// `progress` is clamped to `0...1` (M14 follow-up: `min(1, ...)`), so `unitsDone > unitsTotal`
    /// can't drive a progress bar past 100%.
    private static func testProgressWhenUnitsDoneExceedsUnitsTotal() {
        let task = FileOperationTask(title: "Overshoot", unitsDone: 1500, unitsTotal: 1000)
        report(
            "Model/FileOperationTask",
            "POS: progress is clamped to 1.0 when unitsDone exceeds unitsTotal",
            result: task.progress == 1.0)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
