import Foundation
@testable import Wiles

@MainActor
public struct BackgroundOperationsTests {
    public static func run() {
        testAddTaskAppearsInActiveTasks()
        testUpdateProgressMutatesTheCorrectTask()
        testUpdateProgressForUnknownIdIsANoOp()
        testCompleteTaskRemovesIt()
        testCancelTaskMarksCancelledAndRemoves()
    }

    private static func testAddTaskAppearsInActiveTasks() {
        let service = BackgroundOperationsService.shared
        let before = service.activeTasks.count
        let id = service.addTask(title: "Copying files", totalBytes: 1000)
        defer { service.completeTask(id: id) }

        report("BackgroundOperations", "POS: addTask() appends a new active task", result: service.activeTasks.count == before + 1)
        report(
            "BackgroundOperations",
            "POS: newly added task starts at zero progress",
            result: service.activeTasks.first(where: { $0.id == id })?.progress == 0.0)
    }

    private static func testUpdateProgressMutatesTheCorrectTask() {
        let service = BackgroundOperationsService.shared
        let idA = service.addTask(title: "Task A", totalBytes: 1000)
        let idB = service.addTask(title: "Task B", totalBytes: 1000)
        defer {
            service.completeTask(id: idA)
            service.completeTask(id: idB)
        }

        service.updateProgress(id: idA, bytesTransferred: 500)

        let taskA = service.activeTasks.first(where: { $0.id == idA })
        let taskB = service.activeTasks.first(where: { $0.id == idB })
        report(
            "BackgroundOperations",
            "POS: updateProgress() updates only the targeted task's progress",
            result: taskA?.progress == 0.5 && taskA?.bytesTransferred == 500)
        report("BackgroundOperations", "NEG: updateProgress() does not affect a different task", result: taskB?.progress == 0.0)
    }

    private static func testUpdateProgressForUnknownIdIsANoOp() {
        let service = BackgroundOperationsService.shared
        let before = service.activeTasks
        service.updateProgress(id: UUID(), bytesTransferred: 900)
        report(
            "BackgroundOperations",
            "NEG: updateProgress() with an unknown id does not crash or mutate existing tasks",
            result: service.activeTasks.count == before.count)
    }

    private static func testCompleteTaskRemovesIt() {
        let service = BackgroundOperationsService.shared
        let id = service.addTask(title: "To complete")
        report("BackgroundOperations", "POS: task exists right after being added", result: service.activeTasks.contains { $0.id == id })

        service.completeTask(id: id)
        report("BackgroundOperations", "POS: completeTask() removes the task from activeTasks", result: !service.activeTasks.contains { $0.id == id })
    }

    private static func testCancelTaskMarksCancelledAndRemoves() {
        let service = BackgroundOperationsService.shared
        let id = service.addTask(title: "To cancel")
        service.cancelTask(id: id)
        report("BackgroundOperations", "POS: cancelTask() removes the task (same as completion)", result: !service.activeTasks.contains { $0.id == id })
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
