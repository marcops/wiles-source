import Foundation

public struct DirectoryLoadOptions: Sendable {
    public let showHidden: Bool
    public let showTags: Bool
    public let searchQuery: String
    public let sortOption: SortOption
    public let sortAscending: Bool
    /// Whether the Owner/Group columns are visible and their values are actually needed. Defaults
    /// to `true` (always fetch) so existing call sites that don't pass this explicitly keep their
    /// current behavior; callers that know Owner/Group are hidden can pass `false` to skip the
    /// per-file attributesOfItem(atPath:) syscall entirely.
    public let showOwnerGroup: Bool

    public init(showHidden: Bool, showTags: Bool, searchQuery: String, sortOption: SortOption, sortAscending: Bool, showOwnerGroup: Bool = true) {
        self.showHidden = showHidden
        self.showTags = showTags
        self.searchQuery = searchQuery
        self.sortOption = sortOption
        self.sortAscending = sortAscending
        self.showOwnerGroup = showOwnerGroup
    }
}
