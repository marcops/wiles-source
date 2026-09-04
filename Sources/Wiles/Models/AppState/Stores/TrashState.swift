import Foundation
import GitBeacon

/// Per-window state for the Trash size figure shown in the footer/sidebar, and for driving the
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

    /// In-flight Trash enumeration spawned by `refreshSize()`. Cancelled and replaced on every
    /// call so it never piles up multiple concurrent full-Trash walks.
    var task: Task<Void, Never>?
    /// In-flight `emptyTrash()` operation. Stored so the owning window's teardown can cancel it —
    /// `removeTrashContents` checks `Task.isCancelled` per item.
    private var emptyTask: Task<Void, Never>?
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

    /// `~/.Trash` plus each mounted external volume's `.Trashes/<uid>` (where its deletions land).
    nonisolated static func trashDirectories(fileManager fm: FileManager = .default) -> [URL] {
        var directories: [URL] = [URL.userTrash]
        let uid = String(getuid())
        let volumes = fm.mountedVolumeURLs(includingResourceValuesForKeys: nil, options: [.skipHiddenVolumes]) ?? []
        for volume in volumes where volume.deletingLastPathComponent().path == "/Volumes" {
            let volumeTrash = volume.appendingPathComponent(".Trashes/\(uid)", isDirectory: true)
            if fm.fileExists(atPath: volumeTrash.path) {
                directories.append(volumeTrash)
            }
        }
        return directories
    }

    /// `nonisolated` on purpose: runs inside `Task.detached`, off the main actor, so the
    /// potentially-large Trash enumeration below never blocks the UI.
    private nonisolated static func computeTrashSize() -> TrashSizeResult {
        let directories = trashDirectories()
        guard !directories.isEmpty else { return .noTrash }
        var totalSize: Int64 = 0
        let keys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey]
        for directory in directories {
            // No `.skipsHiddenFiles`: "Empty Trash" removes hidden entries too, so the size must count them.
            guard let enumerator = FileManager.default.enumerator(
                at: directory, includingPropertiesForKeys: keys, options: [],
                // Skip an unreadable subitem instead of aborting the walk (→ undercounted Trash size). R1.
                errorHandler: { _, _ in true }) else { continue }
            while let fileURL = enumerator.nextObject() as? URL {
                if Task.isCancelled {
                    return .cancelled
                }
                if let res = try? fileURL.resourceValues(forKeys: Set(keys)), !(res.isDirectory ?? true), let size = res.fileSize {
                    totalSize += Int64(size)
                }
            }
            if Task.isCancelled {
                return .cancelled
            }
        }
        return .success(totalSize)
    }

    private nonisolated static func removeTrashContents(_ paths: [URL], using fm: FileManager) -> Int {
        var failedCount = 0
        for path in paths {
            if Task.isCancelled {
                break
            }
            do {
                try fm.removeItem(at: path)
            } catch {
                ErrorReporter.report(error, context: "Emptying Trash")
                failedCount += 1
            }
        }
        return failedCount
    }

    /// Enumerates the contents of every directory in `trashDirectories()` (home + external volumes),
    /// off the main actor. `unreadableDirectories` counts the Trash folders that couldn't be listed
    /// at all (e.g. a permission-denied external volume) — those contribute zero URLs, so without
    /// this an empty-trash over an unlistable volume would report "0 failed" = total success even
    /// though that volume's Trash was untouched.
    private nonisolated static func allTrashedItems(using fm: FileManager) -> (items: [URL], unreadableDirectories: Int) {
        allTrashedItems(in: trashDirectories(fileManager: fm), using: fm)
    }

    /// `directories` split out for testing — production always passes `trashDirectories()`.
    nonisolated static func allTrashedItems(
        in directories: [URL], using fm: FileManager) -> (items: [URL], unreadableDirectories: Int) {
        var items: [URL] = []
        var unreadable = 0
        for directory in directories {
            if let contents = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: []) {
                items.append(contentsOf: contents)
            } else if fm.fileExists(atPath: directory.path) {
                // The directory is there but couldn't be read — a real failure, not "no Trash here".
                unreadable += 1
            }
        }
        return (items, unreadable)
    }

    /// Recomputes `sizeString`/`sizeBytes` from a fresh Trash enumeration. Supersedes any
    /// enumeration already in flight instead of piling another one on top of it. The caller
    /// (`refreshTrashSizeIfNeeded`) already gates this to a real Trash visit or the 30s
    /// `shouldRecompute()` clock, so it isn't actually run per navigation/keystroke.
    /// Identifies the most recently started enumeration, so a slower older one can't apply its
    /// result over a newer one — and so a cancel that belongs to the *current* run (teardown, not
    /// a supersede) still clears `isUpdating` instead of leaving the spinner stuck.
    private var currentToken = UUID()

    public func refreshSize() {
        task?.cancel()
        isUpdating = true
        let token = UUID()
        currentToken = token
        task = Task.detached(priority: .background) { [weak self] in
            let result = Self.computeTrashSize()
            await self?.applyTrashSize(result, token: token)
        }
    }

    /// Cancels any in-flight enumeration and clears the spinner — for the owning window's teardown.
    func cancelInFlight() {
        task?.cancel()
        task = nil
        emptyTask?.cancel()
        emptyTask = nil
        currentToken = UUID()
        isUpdating = false
    }

    @MainActor
    private func applyTrashSize(_ result: TrashSizeResult, token: UUID) {
        guard token == currentToken else { return }
        switch result {
        case let .success(totalSize):
            sizeString = ByteFormat.fileSize(totalSize)
            sizeBytes = totalSize
            isUpdating = false
        case .noTrash, .cancelled:
            isUpdating = false
        }
    }

    /// Empties the home Trash and every mounted external volume's Trash, then hops back to the main
    /// actor and calls `onComplete` with the number of items that failed to delete. Deliberately
    /// knows nothing about refreshing the directory listing or surfacing an error to the user —
    /// that's the caller's job.
    public func emptyTrash(onComplete: @escaping @MainActor (Int) -> Void) {
        isUpdating = true
        emptyTask?.cancel()
        emptyTask = Task.detached(priority: .userInitiated) { [weak self] in
            let fm = FileManager.default
            let (paths, unreadableDirectories) = Self.allTrashedItems(using: fm)
            let failedCount = Self.removeTrashContents(paths, using: fm) + unreadableDirectories
            await self?.finishEmptyTrash(failed: failedCount, onComplete: onComplete)
        }
    }

    /// Single main-actor exit point for `emptyTrash`: clears `isUpdating` and hands the caller the
    /// failure count, so every early return and the success path stay in sync.
    @MainActor
    private func finishEmptyTrash(failed: Int, onComplete: @MainActor (Int) -> Void) {
        isUpdating = false
        onComplete(failed)
    }
}
