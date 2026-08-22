import Foundation
import GitBeacon

public extension AppState {
    private enum TrashSizeResult {
        case success(Int64)
        case noTrash
        case cancelled
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
            if let res = try? fileURL.resourceValues(forKeys: Set(keys)), res.isDirectory == false, let size = res.fileSize {
                totalSize += Int64(size)
            }
        }
        guard !Task.isCancelled else { return .cancelled }
        return .success(totalSize)
    }

    func updateTrashSize() {
        // Supersede any enumeration already in flight instead of piling another one on top of it —
        // this fires on every navigation/search keystroke via refreshCurrentDirectory().
        transient.trashSizeTask?.cancel()
        transient.isTrashUpdating = true
        transient.trashSizeTask = Task.detached(priority: .background) { [weak self] in
            switch Self.computeTrashSize() {
            case let .success(totalSize):
                let sizeStr = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
                await MainActor.run { [weak self] in
                    self?.transient.trashSizeString = sizeStr
                    self?.transient.trashSizeBytes = totalSize
                    self?.transient.isTrashUpdating = false
                }
            case .noTrash:
                await MainActor.run { [weak self] in self?.transient.isTrashUpdating = false }
            case .cancelled:
                break
            }
        }
    }

    func performEmptyTrash() {
        Task { @MainActor in
            self.transient.isTrashUpdating = true
        }
        Task.detached(priority: .userInitiated) {
            let trashURL = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first
            guard let url = trashURL else {
                await MainActor.run { [weak self] in self?.transient.isTrashUpdating = false }
                return
            }
            let fm = FileManager.default
            guard let paths = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: []) else {
                await MainActor.run { [weak self] in self?.transient.isTrashUpdating = false }
                return
            }
            let failedCount = Self.removeTrashContents(paths, using: fm)
            await MainActor.run { [weak self] in
                self?.updateTrashSize()
                self?.refreshCurrentDirectory()
                if failedCount > 0, let self {
                    showError(String(format: tr(.emptyTrashDeleteFailed), failedCount))
                }
            }
        }
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
}
