@testable import Wiles
import Foundation

@MainActor
public struct FileOperationTaskTests {
    public static func run() {
        let task = FileOperationTask(
            title: "Copying files",
            progress: 0.5,
            bytesTransferred: 500,
            totalBytes: 1000,
            isCancelled: false
        )
        report("Model/FileOperationTask", "POS: Task title matches input", result: task.title == "Copying files")
        report("Model/FileOperationTask", "POS: Task progress matches 0.5", result: task.progress == 0.5)

        var cancelledTask = task
        cancelledTask.isCancelled = true
        report("Model/FileOperationTask", "NEG: Cancelled flag status set correctly", result: cancelledTask.isCancelled)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
