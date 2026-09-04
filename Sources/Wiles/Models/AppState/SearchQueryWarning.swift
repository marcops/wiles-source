import Foundation

/// Why a non-empty search query is legitimately returning nothing — surfaced in the empty-results
/// view so a too-short content query or an uncompilable regex doesn't just look like "no matches".
public enum SearchQueryWarning: Equatable {
    case contentQueryTooShort(minimum: Int)
    case invalidRegex
    /// A `size:`/`date:` filter token whose value can't parse (`size:>10zz`, `date:>abc`), which
    /// makes every file fail the filter — 0 results with no visible reason.
    case invalidFilterToken(token: String)
}
