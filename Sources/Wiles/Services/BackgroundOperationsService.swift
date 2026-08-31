import Foundation
import Observation

/// Per-window (one instance per `AppState`), not a `.shared` singleton — `activeTasks` is "what
/// THIS window is doing right now"; a shared instance surfaced one window's copy/move progress in
/// every other window's footer, and kept a closed window's cancellation handler alive.
@Observable
@MainActor
public final class BackgroundOperationsService {
    public var activeTasks: [FileOperationTask] = []

    /// Per-task cancellation, kept off `FileOperationTask` (a plain `Sendable` display model).
    /// Without this, the popover's ✕ button only hid the progress bar while the copy/move/delete
    /// kept running.
    private var cancellationHandlers: [UUID: @Sendable () -> Void] = [:]

    public init() { }

    public func addTask(title: String, totalUnits: Int64 = 0) -> UUID {
        let task = FileOperationTask(title: title, unitsTotal: totalUnits)
        activeTasks.append(task)
        return task.id
    }

    /// Wires the popover's cancel button for `id` to actually stop the underlying work. The
    /// operation's own loop must check `Task.isCancelled` for this to take effect.
    public func registerCancellation(id: UUID, _ handler: @escaping @Sendable () -> Void) {
        cancellationHandlers[id] = handler
    }

    public func updateProgress(id: UUID, unitsDone: Int64) {
        guard let index = activeTasks.firstIndex(where: { $0.id == id }) else { return }
        activeTasks[index].unitsDone = unitsDone
    }

    public func completeTask(id: UUID) {
        activeTasks.removeAll(where: { $0.id == id })
        cancellationHandlers[id] = nil
    }

    public func cancelTask(id: UUID) {
        cancellationHandlers[id]?()
        completeTask(id: id)
    }
}
