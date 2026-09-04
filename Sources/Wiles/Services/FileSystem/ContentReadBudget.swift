import Foundation

/// A per-search cap on the total bytes read from disk for content matching. A recursive
/// "search everywhere" with Content/Both scope otherwise reads every text file under `~` (up to
/// `maxContentSearchFileBytes` each) synchronously inside the crawl, with no ceiling on the number
/// of files — gigabytes of I/O for one stray keystroke.
///
/// `nil` everywhere it's optional means "unlimited": the normal single-folder listing is already
/// bounded by `directoryListingLimit` entries and needs no budget.
public final class ContentReadBudget {
    public private(set) var bytesRemaining: Int
    public private(set) var exhausted = false

    public init(totalBytes: Int) {
        bytesRemaining = totalBytes
    }

    /// `false` once the budget is spent — the caller then stops reading new files from disk.
    public func canRead() -> Bool {
        bytesRemaining > 0
    }

    public func consume(_ bytes: Int) {
        bytesRemaining -= bytes
        if bytesRemaining <= 0 {
            exhausted = true
        }
    }
}
