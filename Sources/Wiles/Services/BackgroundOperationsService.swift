import Foundation
import Observation

@Observable
@MainActor
public final class BackgroundOperationsService {
    public static let shared = BackgroundOperationsService()

    public var activeTasks: [FileOperationTask] = []

    private init() {}

    public func addTask(title: String, totalBytes: Int64 = 0) -> UUID {
        let task = FileOperationTask(title: title, totalBytes: totalBytes)
        activeTasks.append(task)
        return task.id
    }

    public func updateProgress(id: UUID, progress: Double, bytesTransferred: Int64 = 0) {
        guard let index = activeTasks.firstIndex(where: { $0.id == id }) else { return }
        activeTasks[index].progress = progress
        activeTasks[index].bytesTransferred = bytesTransferred
    }

    public func completeTask(id: UUID) {
        activeTasks.removeAll(where: { $0.id == id })
    }

    public func cancelTask(id: UUID) {
        if let index = activeTasks.firstIndex(where: { $0.id == id }) {
            activeTasks[index].isCancelled = true
        }
        completeTask(id: id)
    }
}
