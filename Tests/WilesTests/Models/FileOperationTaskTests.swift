import Foundation
@testable import Wiles

@MainActor
public struct FileOperationTaskTests {
    public static func run() {
        let task = FileOperationTask(
            title: "Copying files",
            bytesTransferred: 500,
            totalBytes: 1000)
        report("Model/FileOperationTask", "POS: Task title matches input", result: task.title == "Copying files")
        report("Model/FileOperationTask", "POS: Task progress derives from bytesTransferred/totalBytes", result: task.progress == 0.5)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
