import Foundation
import GitBeacon

/// Per-window state for the `~/.Trash` size figure shown in the footer/sidebar, and for driving the
/// empty-trash operation. Owned by `FileSystemStore` (`fileSystem.trash`) rather than `TransientStore`
/// so each window's Trash bookkeeping — in-flight enumeration task, last-known size, opportunistic
/// recompute timestamp — is fully independent instead of shared app-wide.
@Observable
@MainActor
public final class TrashState {
    private enum TrashSizeResult {
        case success(Int64)
        case noTrash
        case cancelled
    }

    /// In-flight `~/.Trash` enumeration spawned by `refreshSize()`. Cancelled and replaced on every
    /// call so it never piles up multiple concurrent full-Trash walks.
    var task: Task<Void, Never>?
    /// Timestamp of the last trash-size enumeration triggered opportunistically from
    /// `refreshCurrentDirectory()`, used to coalesce it to a coarse interval instead of firing on
    /// every navigation/search keystroke/FSEvents refresh.
    var lastOpportunisticCheck: Date = .distantPast
    static let recomputeInterval: TimeInterval = 30

    public var sizeString: String = ""
    public var sizeBytes: Int64 = 0
    public var isUpdating: Bool = false

    public init() { }

    /// Checks whether at least `recomputeInterval` has elapsed since the last opportunistic check
    /// and, if so, atomically stamps `lastOpportunisticCheck` to `now` in the same call — callers
    /// can't forget to record the check the way a separate read-then-write pair could.
    func shouldRecompute(now: Date = Date()) -> Bool {
        guard now.timeIntervalSince(lastOpportunisticCheck) >= Self.recomputeInterval else { return false }
        lastOpportunisticCheck = now
        return true
    }

    /// `nonisolated` on purpose: runs inside `Task.detached`, off the main actor, so the
    /// potentially-large `~/.Trash` enumeration below never blocks the UI.
    private nonisolated static func computeTrashSize() -> TrashSizeResult {
        guard let url = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first else {
            return .noTrash
        }
        var totalSize: Int64 = 0
        let keys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey]
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else {
            return .noTrash
        }
        while let fileURL = enumerator.nextObject() as? URL {
            if Task.isCancelled {
                return .cancelled
            }
            if let res = try? fileURL.resourceValues(forKeys: Set(keys)), !(res.isDirectory ?? true), let size = res.fileSize {
                totalSize += Int64(size)
            }
        }
        guard !Task.isCancelled else { return .cancelled }
        return .success(totalSize)
    }

    private nonisolated static func removeTrashContents(_ paths: [URL], using fm: FileManager) -> Int {
        var failedCount = 0
        for path in paths {
            do {
                try fm.removeItem(at: path)
            } catch {
                ErrorReporter.report(error, context: "Emptying Trash")
                failedCount += 1
            }
        }
        return failedCount
    }

    /// Recomputes `sizeString`/`sizeBytes` from a fresh `~/.Trash` enumeration. Supersedes any
    /// enumeration already in flight instead of piling another one on top of it — this fires on every
    /// navigation/search keystroke via `refreshCurrentDirectory()`.
    public func refreshSize() {
        task?.cancel()
        isUpdating = true
        task = Task.detached(priority: .background) { [weak self] in
            switch Self.computeTrashSize() {
            case let .success(totalSize):
                let sizeStr = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
                await MainActor.run { [weak self] in
                    self?.sizeString = sizeStr
                    self?.sizeBytes = totalSize
                    self?.isUpdating = false
                }
            case .noTrash:
                await MainActor.run { [weak self] in self?.isUpdating = false }
            case .cancelled:
                break
            }
        }
    }

    /// Empties `~/.Trash`, then hops back to the main actor and calls `onComplete` with the number of
    /// items that failed to delete. Deliberately knows nothing about refreshing the directory listing
    /// or surfacing an error to the user — that's the caller's job.
    public func emptyTrash(onComplete: @escaping @MainActor (Int) -> Void) {
        isUpdating = true
        Task.detached(priority: .userInitiated) { [weak self] in
            let trashURL = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first
            guard let url = trashURL else {
                await MainActor.run {
                    self?.isUpdating = false
                    onComplete(0)
                }
                return
            }
            let fm = FileManager.default
            guard let paths = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: []) else {
                await MainActor.run {
                    self?.isUpdating = false
                    onComplete(0)
                }
                return
            }
            let failedCount = Self.removeTrashContents(paths, using: fm)
            await MainActor.run {
                onComplete(failedCount)
            }
        }
    }
}
