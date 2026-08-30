import Foundation

/// A search-bar query analysed once per directory load rather than once per candidate file:
/// its whitespace-split tokens, the compiled regex for each regex/wildcard token, and the union
/// of `URLResourceKey`s the present tokens (plus the scope) will need from `resourceValues`.
/// Built by `SearchFilterService.parsedQuery(...)`, consumed by `SearchFilterService.matchesSearch`.
public struct ParsedSearchQuery: Sendable {
    let tokens: [String]
    let tokenRegexes: [String: NSRegularExpression]
    let resourceKeys: Set<URLResourceKey>
    let isEmpty: Bool
}
