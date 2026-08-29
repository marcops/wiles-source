import Foundation

/// Batch rename isn't transactional — carries both what succeeded and what failed per item.
public struct BatchRenameResult {
    public let renamedURLs: [URL]
    /// old→new URL for every item actually renamed on disk (excludes no-op skips where the
    /// computed name matched the original) — lets the caller record one undo action per rename.
    public let renamedPairs: [(old: URL, new: URL)]
    public let failures: [(item: FileItem, error: any Error)]

    /// `nil` when every item succeeded; a single-item batch reports its one error directly. The
    /// caller passes this straight to `AppState.showError`, which localizes it in the app language.
    public var failureError: WilesError? {
        guard !failures.isEmpty else { return nil }
        let totalCount = renamedURLs.count + failures.count
        if totalCount == 1, let only = failures.first?.error {
            return (only as? WilesError) ?? .operationFailed(reason: only.localizedDescription)
        }
        let detail = failures.map { "\($0.item.name): \($0.error.localizedDescription)" }.joined(separator: "; ")
        return .localized(key: .batchRenamePartialFailure, arguments: ["\(renamedURLs.count)", "\(totalCount)", detail])
    }
}
