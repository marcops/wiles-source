import Foundation

/// Why a non-empty search query is legitimately returning nothing — surfaced in the empty-results
/// view so a too-short content query or an uncompilable regex doesn't just look like "no matches".
public enum SearchQueryWarning: Equatable {
    case contentQueryTooShort(minimum: Int)
    case invalidRegex
}
