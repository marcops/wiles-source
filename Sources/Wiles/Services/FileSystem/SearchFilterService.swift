import Foundation
import UniformTypeIdentifiers

/// Parses and evaluates the search-bar query language (plain text, `r:` regex, and
/// `date:`/`size:`/`kind:`/`ext:`/`tag:` filter tokens) against candidate file URLs.
public struct SearchFilterService: Sendable {
    /// Shortest plain-text query that content search will act on — anything shorter is a silent
    /// no-op, so `queryWarning` surfaces it as `.contentQueryTooShort` instead.
    public static let minContentQueryLength = 3
    /// Largest file whose bytes are read for a content-search match — a bigger read would stall.
    static let maxContentSearchFileBytes = 2_000_000
    /// Total disk bytes a single recursive "search everywhere" is allowed to read for content
    /// matching before it stops opening new files (finding MM-096). Cache hits don't count.
    static let recursiveContentByteBudget = 128 * 1024 * 1024

    /// The one whitespace-split used everywhere the query string is broken into tokens.
    static func tokens(of query: String) -> [String] {
        query.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
    }

    /// File attributes any present filter token might need, fetched once per candidate file so a
    /// multi-token query (`date:>7d size:>1m kind:folder tag:x`) does a single `resourceValues`
    /// call instead of one per token.
    struct PrefetchedAttributes {
        let url: URL
        var modificationDate: Date?
        var fileSize: Int?
        var isDirectory = false
        var tagNames: [String]?
    }

    /// `hidden:true` is a global search setting, not a per-file predicate like `date:`/`kind:`/
    /// `tag:`, so it can't be evaluated inside `matchesToken` — it has to be pulled out of the
    /// query before the remaining tokens are matched against each candidate file (otherwise it'd
    /// fall through to a literal filename-contains-"hidden:true" text match). Returns the query
    /// with that token stripped, plus whether it was present.
    public static func extractHiddenFlag(from query: String) -> (query: String, includeHidden: Bool) {
        let tokens = tokens(of: query)
        guard tokens.contains(where: { $0.lowercased() == "hidden:true" }) else { return (query, false) }
        let remaining = tokens.filter { $0.lowercased() != "hidden:true" }.joined(separator: " ")
        return (remaining, true)
    }

    /// Whole-token, case-insensitive membership test for a `prefix:value` filter token in `query`.
    public static func containsToken(_ token: String, in query: String) -> Bool {
        let lowerToken = token.lowercased()
        return tokens(of: query).contains { $0.lowercased() == lowerToken }
    }

    /// Toggles a single `prefix:value` filter token in `query`: strips it if already present
    /// (case-insensitive, whole-token), otherwise appends it — all other free text and filter
    /// tokens are preserved. Generalizes the append/strip behavior of `extractHiddenFlag`.
    public static func toggleToken(_ token: String, in query: String) -> String {
        let parts = tokens(of: query)
        let lowerToken = token.lowercased()
        if parts.contains(where: { $0.lowercased() == lowerToken }) {
            return parts.filter { $0.lowercased() != lowerToken }.joined(separator: " ")
        }
        return (parts + [token]).joined(separator: " ")
    }

    /// Like `toggleToken`, but for a single-choice group (`kind:`, `date:`): activating one token
    /// drops every other token sharing `groupPrefix` so `kind:image` + `kind:doc` (AND → nothing)
    /// can't happen. Re-activating the same token still turns it off.
    public static func toggleExclusiveToken(_ token: String, groupPrefix: String, in query: String) -> String {
        let parts = tokens(of: query)
        let lowerToken = token.lowercased()
        if parts.contains(where: { $0.lowercased() == lowerToken }) {
            return parts.filter { $0.lowercased() != lowerToken }.joined(separator: " ")
        }
        let lowerPrefix = groupPrefix.lowercased()
        return (parts.filter { !$0.lowercased().hasPrefix(lowerPrefix) } + [token]).joined(separator: " ")
    }

    /// Splits `query` into everything except the first `prefix…` token (case-insensitive,
    /// whole-token) and that token's value (the text after `prefix`). Mirrors `extractHiddenFlag`
    /// for a prefix whose value isn't known ahead of time (`tag:`), so a caller can toggle just
    /// that token without discarding the rest of the query. Returns `(query, nil)` when absent.
    public static func extractPrefixedToken(prefix: String, from query: String) -> (remaining: String, value: String?) {
        let tokens = tokens(of: query)
        guard let match = tokens.first(where: { $0.lowercased().hasPrefix(prefix.lowercased()) }) else {
            return (query, nil)
        }
        let remaining = tokens.filter { $0.lowercased() != match.lowercased() }.joined(separator: " ")
        return (remaining, String(match.dropFirst(prefix.count)))
    }

    /// The tag when `query` is exactly one `tag:value` token and nothing else — the case the header
    /// renders as a non-editable tag pill rather than the raw editable search field.
    public static func soleTagValue(in query: String) -> String? {
        let parts = tokens(of: query)
        guard parts.count == 1, let only = parts.first, only.lowercased().hasPrefix("tag:") else { return nil }
        let value = String(only.dropFirst("tag:".count))
        return value.isEmpty ? nil : value
    }

    /// Toggles a `tag:<tag>` token in `query`: removes it when that exact tag is already the active
    /// one, otherwise swaps in the new tag while preserving any free text / other tokens. A single
    /// `tag:` token at a time — picking a different tag replaces the current one.
    public static func toggledTagQuery(tag: String, in query: String) -> String {
        let (remaining, currentTag) = extractPrefixedToken(prefix: "tag:", from: query)
        if currentTag?.lowercased() == tag.lowercased() {
            return remaining
        }
        return remaining.isEmpty ? "tag:\(tag)" : "\(remaining) tag:\(tag)"
    }

    /// Builds a regex for each individual token that looks like one (`r:` prefix, or contains
    /// `*`/`^`/`$`), keyed by the token text — computed once per query and reused across every
    /// candidate file, instead of recompiling per file. Filter tokens (`date:`/`size:`/`kind:`/
    /// `ext:`/`tag:`) never reach `matchesTextOrRegex`, so they're skipped here.
    public static func parseTokenRegexes(query: String, caseSensitive: Bool) -> [String: NSRegularExpression] {
        let options: NSRegularExpression.Options = caseSensitive ? [] : [.caseInsensitive]
        var result: [String: NSRegularExpression] = [:]
        let tokens = tokens(of: query)
        for token in tokens {
            let lowerToken = token.lowercased()
            guard !isFilterToken(lowerToken) else { continue }
            let pattern: String
            if token.hasPrefix("r:") {
                pattern = String(token.dropFirst(2))
            } else if containsRegexMetacharacter(token) {
                pattern = token
            } else {
                continue
            }
            result[token] = try? NSRegularExpression(pattern: pattern, options: options)
        }
        return result
    }

    /// Why the current query is producing no matches when it visually looks valid: a `r:`/wildcard
    /// token that doesn't compile, or (for a Content/Both search) a plain-text query too short for
    /// content search to act on. Returns `nil` when nothing is wrong with the query itself.
    /// Pure — used by the empty-results view to explain the silence.
    public static func queryWarning(for query: String, scope: SearchScope) -> SearchQueryWarning? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let tokens = tokens(of: trimmed)

        var plainTextTokens: [String] = []
        for token in tokens {
            let lower = token.lowercased()
            if isFilterToken(lower) || lower == "hidden:true" {
                if invalidFilterTokenValue(lower) {
                    return .invalidFilterToken(token: token)
                }
                continue
            }
            if token.hasPrefix("r:") || containsRegexMetacharacter(token) {
                let pattern = token.hasPrefix("r:") ? String(token.dropFirst(2)) : token
                if (try? NSRegularExpression(pattern: pattern)) == nil {
                    return .invalidRegex
                }
            } else {
                plainTextTokens.append(token)
            }
        }

        guard scope != .name else { return nil }
        let plainText = plainTextTokens.joined(separator: " ")
        if !plainText.isEmpty, plainText.count < minContentQueryLength {
            return .contentQueryTooShort(minimum: minContentQueryLength)
        }
        return nil
    }

    private static func containsRegexMetacharacter(_ token: String) -> Bool {
        token.contains("*") || token.contains("^") || token.contains("$")
    }

    private static func isFilterToken(_ lowerToken: String) -> Bool {
        lowerToken.hasPrefix("date:") || lowerToken.hasPrefix("size:") || lowerToken.hasPrefix("kind:")
            || lowerToken.hasPrefix("ext:") || lowerToken.hasPrefix("tag:")
    }

    /// `true` when a `size:` / `date:` token's value can't parse at all, so `matchesSizeFilter` /
    /// `matchesDateFilter` reject every file — the query looks valid but is guaranteed empty
    /// (finding ML-140). `kind:` / `ext:` / `tag:` accept any string (they fall back to a substring
    /// match), so they're never "invalid" this way.
    private static func invalidFilterTokenValue(_ lowerToken: String) -> Bool {
        if lowerToken.hasPrefix("size:") {
            return !isParsableSizeFilterValue(String(lowerToken.dropFirst(5)))
        }
        if lowerToken.hasPrefix("date:") {
            return !isParsableDateFilterValue(String(lowerToken.dropFirst(5)))
        }
        return false
    }

    private static func isParsableSizeFilterValue(_ value: String) -> Bool {
        let (_, valueStr) = splitOperator(from: value)
        let digits = valueStr.filter(\.isNumber)
        guard !digits.isEmpty, Int64(digits) != nil else { return false }
        return sizeFilterMultiplier(unit: valueStr.filter(\.isLetter)) != nil
    }

    private static func isParsableDateFilterValue(_ value: String) -> Bool {
        if value == "today" || value == "yesterday" {
            return true
        }
        let (_, valueStr) = splitOperator(from: value)
        let digits = valueStr.filter(\.isNumber)
        return !digits.isEmpty && Int(digits) != nil
    }

    /// Tokenizes and analyses `query` **once** per load — split tokens, compiled regexes, and the
    /// resource-key union — so `matchesSearch` does none of that per candidate file.
    public static func parsedQuery(query: String, scope: SearchScope, caseSensitive: Bool) -> ParsedSearchQuery {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = tokens(of: trimmed)
        return ParsedSearchQuery(
            tokens: tokens,
            tokenRegexes: parseTokenRegexes(query: query, caseSensitive: caseSensitive),
            resourceKeys: resourceKeys(for: tokens, scope: scope),
            isEmpty: trimmed.isEmpty)
    }

    private static func resourceKeys(for tokens: [String], scope: SearchScope) -> Set<URLResourceKey> {
        var keys: Set<URLResourceKey> = []
        for token in tokens {
            let lower = token.lowercased()
            if lower.hasPrefix("date:") {
                keys.insert(.contentModificationDateKey)
            } else if lower.hasPrefix("size:") {
                keys.insert(.fileSizeKey)
            } else if lower.hasPrefix("kind:") {
                keys.insert(.isDirectoryKey)
            } else if lower.hasPrefix("tag:") {
                keys.insert(.tagNamesKey)
            }
        }
        if scope != .name {
            keys.insert(.fileSizeKey)
            keys.insert(.contentModificationDateKey) // content-match cache key (path|mtime|size)
        }
        return keys
    }

    /// `scope` is the explicit Name/Content/Both menu choice — no implicit fallback. Each token is
    /// matched against its own regex, if it has one, never the whole query string.
    /// `contentBudget` (recursive "search everywhere" only) caps total bytes read from disk for
    /// content matching across the whole crawl — see `ContentReadBudget` / finding MM-096. `nil`
    /// leaves content reads unbounded, which is fine for a single-folder listing.
    public static func matchesSearch(
        fileURL: URL, parsed: ParsedSearchQuery, scope: SearchScope, caseSensitive: Bool,
        contentBudget: ContentReadBudget? = nil) -> Bool {
        guard !parsed.isEmpty else { return true }

        let options = MatchOptions(scope: scope, caseSensitive: caseSensitive, contentBudget: contentBudget)
        let attributes = prefetchAttributes(for: fileURL, resourceKeys: parsed.resourceKeys)
        for token in parsed.tokens
            where !matchesToken(token: token, regex: parsed.tokenRegexes[token], attributes: attributes, options: options) {
            return false
        }
        return true
    }

    /// The per-search constants (don't vary per token) threaded into the token matchers.
    private struct MatchOptions {
        let scope: SearchScope
        let caseSensitive: Bool
        /// Recursive "search everywhere" only — total disk-read cap for content matching (MM-096).
        let contentBudget: ContentReadBudget?
    }

    /// One `resourceValues` fetch covering `resourceKeys` (precomputed by `parsedQuery`). Returns
    /// empty values (all matchers then fail closed) when the file is gone or nothing needs disk.
    private static func prefetchAttributes(for fileURL: URL, resourceKeys keys: Set<URLResourceKey>) -> PrefetchedAttributes {
        guard !keys.isEmpty, let values = try? fileURL.resourceValues(forKeys: keys) else {
            return PrefetchedAttributes(url: fileURL)
        }
        return PrefetchedAttributes(
            url: fileURL,
            modificationDate: values.contentModificationDate,
            fileSize: values.fileSize,
            isDirectory: values.isDirectory ?? false,
            tagNames: values.tagNames)
    }

    private static func matchesToken(
        token: String, regex: NSRegularExpression?, attributes: PrefetchedAttributes, options: MatchOptions) -> Bool {
        let lowerToken = token.lowercased()
        if lowerToken.hasPrefix("date:") {
            return matchesDateFilter(token: String(token.dropFirst(5)), attributes: attributes)
        } else if lowerToken.hasPrefix("size:") {
            return matchesSizeFilter(token: String(token.dropFirst(5)), attributes: attributes)
        } else if lowerToken.hasPrefix("kind:") || lowerToken.hasPrefix("ext:") {
            let prefix = lowerToken.hasPrefix("kind:") ? 5 : 4
            return matchesKindFilter(token: String(token.dropFirst(prefix)), attributes: attributes)
        } else if lowerToken.hasPrefix("tag:") {
            return matchesTagFilter(tag: String(token.dropFirst(4)), attributes: attributes)
        }
        return matchesTextOrRegex(token: token, regex: regex, attributes: attributes, options: options)
    }

    private static func matchesDateFilter(token: String, attributes: PrefetchedAttributes) -> Bool {
        guard let modified = attributes.modificationDate else { return false }
        let lower = token.lowercased()
        if lower == "today" {
            return Calendar.current.isDateInToday(modified)
        }
        if lower == "yesterday" {
            return Calendar.current.isDateInYesterday(modified)
        }

        let (op, valueStr) = splitOperator(from: lower)
        guard let num = Int(valueStr.filter(\.isNumber)) else { return false }
        let unit = valueStr.filter(\.isLetter)
        let seconds = dateFilterSeconds(num: num, unit: unit)

        // "date:>=Nd" means "at least N days old" (age >= N), which is modified-time <= targetDate
        // (further in the past); "date:<Nd" means more recent than N days ago, i.e. modified > targetDate.
        // The previous version had these two branches swapped, so >= matched recent files and
        // < matched old ones — exactly backwards from what the query syntax implies.
        let targetDate = Date().addingTimeInterval(-seconds)
        switch op {
        case "<", "<=": return modified > targetDate
        default: return modified <= targetDate
        }
    }

    private static func dateFilterSeconds(num: Int, unit: String) -> TimeInterval {
        switch unit {
        case "h": Double(num) * 3600
        case "w": Double(num) * 7 * 86400
        case "m": Double(num) * 30 * 86400
        case "y": Double(num) * 365 * 86400
        default: Double(num) * 86400
        }
    }

    /// Splits a leading comparison operator (`>=`, `<=`, `>`, `<`, `=`) off a lowercased filter
    /// value string, defaulting to `>=` when none is present.
    private static func splitOperator(from lower: String) -> (op: String, valueStr: String) {
        var valueStr = lower
        var op = ">="
        if valueStr.hasPrefix(">=") || valueStr.hasPrefix("<=") {
            op = String(valueStr.prefix(2))
            valueStr = String(valueStr.dropFirst(2))
        } else if isSingleCharComparisonOperator(valueStr) {
            op = String(valueStr.prefix(1))
            valueStr = String(valueStr.dropFirst(1))
        }
        return (op, valueStr)
    }

    private static func isSingleCharComparisonOperator(_ valueStr: String) -> Bool {
        valueStr.hasPrefix(">") || valueStr.hasPrefix("<") || valueStr.hasPrefix("=")
    }

    private static func matchesSizeFilter(token: String, attributes: PrefetchedAttributes) -> Bool {
        guard let size = attributes.fileSize else { return false }
        let (op, valueStr) = splitOperator(from: token.lowercased())

        let digits = valueStr.filter(\.isNumber)
        guard let num = Int64(digits), !digits.isEmpty else { return false }
        let unit = valueStr.filter(\.isLetter)
        guard let multiplier = sizeFilterMultiplier(unit: unit) else { return false }
        let targetBytes = num * multiplier

        switch op {
        case "<": return size < targetBytes
        case "<=": return size <= targetBytes
        case "=": return size == targetBytes
        case ">": return size > targetBytes
        default: return size >= targetBytes
        }
    }

    /// Matches an explicit unit word exactly. An empty unit defaults to MB (the documented bare
    /// `size:>10` behavior); an unrecognized unit (`10bites`, `10xb`) returns `nil` so the whole
    /// size filter fails instead of silently being treated as MB.
    private static func sizeFilterMultiplier(unit: String) -> Int64? {
        switch unit {
        case "", "m", "mb", "mib": 1024 * 1024
        case "b", "byte", "bytes": 1
        case "k", "kb", "kib": 1024
        case "g", "gb", "gib": 1024 * 1024 * 1024
        default: nil
        }
    }

    private static func matchesKindFilter(token: String, attributes: PrefetchedAttributes) -> Bool {
        let lower = token.lowercased()
        let ext = attributes.url.pathExtension.lowercased()

        switch lower {
        case "image", "img", "images":
            return extensionConforms(ext, to: .image)
        case "doc", "document", "documents":
            return FileKindCatalog.isDocument(ext)
        case "code", "source":
            return FileKindCatalog.isCode(ext)
        case "pdf":
            return ext == "pdf"
        case "folder", "dir", "directory":
            return attributes.isDirectory
        case "archive", "zip":
            return extensionConforms(ext, to: .archive)
        default:
            return ext == lower || attributes.url.lastPathComponent.lowercased().contains(lower)
        }
    }

    private static func extensionConforms(_ ext: String, to type: UTType) -> Bool {
        guard !ext.isEmpty, let fileType = UTType(filenameExtension: ext) else { return false }
        return fileType.conforms(to: type)
    }

    private static func matchesTagFilter(tag: String, attributes: PrefetchedAttributes) -> Bool {
        let targetTag = tag.lowercased()
        guard let tagArray = attributes.tagNames else { return false }
        return tagArray.contains { $0.lowercased() == targetTag }
    }

    private static func matchesTextOrRegex(
        token: String, regex: NSRegularExpression?, attributes: PrefetchedAttributes, options: MatchOptions) -> Bool {
        let caseSensitive = options.caseSensitive
        switch options.scope {
        case .name:
            return matchesFileName(token: token, regex: regex, caseSensitive: caseSensitive, attributes: attributes)
        case .content:
            return matchesContent(query: token, caseSensitive: caseSensitive, attributes: attributes, budget: options.contentBudget)
        case .both:
            return matchesFileName(token: token, regex: regex, caseSensitive: caseSensitive, attributes: attributes)
                || matchesContent(query: token, caseSensitive: caseSensitive, attributes: attributes, budget: options.contentBudget)
        }
    }

    private static func matchesFileName(token: String, regex: NSRegularExpression?, caseSensitive: Bool, attributes: PrefetchedAttributes) -> Bool {
        let fileName = attributes.url.lastPathComponent
        let nameMatches = caseSensitive ? fileName.contains(token) : fileName.localizedCaseInsensitiveContains(token)
        if nameMatches {
            return true
        }
        guard let regex else { return false }
        let range = NSRange(location: 0, length: fileName.utf16.count)
        return regex.firstMatch(in: fileName, options: [], range: range) != nil
    }

    /// Bounded `(path|mtime|size)` → file-text cache so a content search doesn't re-read every
    /// candidate file from disk on every keystroke of the debounced refresh.
    private nonisolated(unsafe) static let contentCache: NSCache<NSString, NSString> = {
        let cache = NSCache<NSString, NSString>()
        cache.countLimit = 4000
        cache.totalCostLimit = 64 * 1024 * 1024
        return cache
    }()

    private static func matchesContent(
        query: String, caseSensitive: Bool, attributes: PrefetchedAttributes, budget: ContentReadBudget?) -> Bool {
        guard query.count >= minContentQueryLength else { return false }
        guard FileKindCatalog.isText(attributes.url.pathExtension) else { return false }
        guard let size = attributes.fileSize, size < maxContentSearchFileBytes else { return false }
        guard let content = cachedTextContent(
            of: attributes.url, mtime: attributes.modificationDate, size: size, budget: budget) else { return false }
        return caseSensitive ? content.contains(query) : content.localizedCaseInsensitiveContains(query)
    }

    private static func cachedTextContent(of fileURL: URL, mtime: Date?, size: Int, budget: ContentReadBudget?) -> String? {
        let key = "\(fileURL.path)|\(mtime?.timeIntervalSinceReferenceDate ?? 0)|\(size)" as NSString
        if let hit = contentCache.object(forKey: key) {
            return hit as String
        }
        // Cache miss ⇒ this call would hit the disk. Stop once the recursive search has spent its
        // total read budget (finding MM-096); a `nil` budget is unbounded.
        if let budget, !budget.canRead() {
            return nil
        }
        guard let text = readTextContent(of: fileURL) else { return nil }
        budget?.consume(text.utf8.count)
        contentCache.setObject(text as NSString, forKey: key, cost: text.utf8.count)
        return text
    }

    /// Reads a text file as UTF-8, falling back to the file's own declared encoding and then
    /// ISO Latin-1 (which never fails to decode) so a non-UTF-8 text file isn't silently skipped
    /// by content search.
    private static func readTextContent(of fileURL: URL) -> String? {
        if let utf8 = try? String(contentsOf: fileURL, encoding: .utf8) {
            return utf8
        }
        var usedEncoding = String.Encoding.utf8
        if let detected = try? String(contentsOf: fileURL, usedEncoding: &usedEncoding) {
            return detected
        }
        return try? String(contentsOf: fileURL, encoding: .isoLatin1)
    }
}
