import Foundation
import UniformTypeIdentifiers

/// Parses and evaluates the search-bar query language (plain text, `r:` regex, and
/// `date:`/`size:`/`kind:`/`ext:`/`tag:` filter tokens) against candidate file URLs.
public struct SearchFilterService: Sendable {
    /// Shortest plain-text query that content search will act on — anything shorter is a silent
    /// no-op, so `queryWarning` surfaces it as `.contentQueryTooShort` instead.
    public static let minContentQueryLength = 3

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
        let tokens = query.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard tokens.contains(where: { $0.lowercased() == "hidden:true" }) else { return (query, false) }
        let remaining = tokens.filter { $0.lowercased() != "hidden:true" }.joined(separator: " ")
        return (remaining, true)
    }

    /// Whole-token, case-insensitive membership test for a `prefix:value` filter token in `query`.
    public static func containsToken(_ token: String, in query: String) -> Bool {
        let lowerToken = token.lowercased()
        return query.components(separatedBy: .whitespaces).contains { $0.lowercased() == lowerToken }
    }

    /// Toggles a single `prefix:value` filter token in `query`: strips it if already present
    /// (case-insensitive, whole-token), otherwise appends it — all other free text and filter
    /// tokens are preserved. Generalizes the append/strip behavior of `extractHiddenFlag`.
    public static func toggleToken(_ token: String, in query: String) -> String {
        let parts = query.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        let lowerToken = token.lowercased()
        if parts.contains(where: { $0.lowercased() == lowerToken }) {
            return parts.filter { $0.lowercased() != lowerToken }.joined(separator: " ")
        }
        return (parts + [token]).joined(separator: " ")
    }

    /// Splits `query` into everything except the first `prefix…` token (case-insensitive,
    /// whole-token) and that token's value (the text after `prefix`). Mirrors `extractHiddenFlag`
    /// for a prefix whose value isn't known ahead of time (`tag:`), so a caller can toggle just
    /// that token without discarding the rest of the query. Returns `(query, nil)` when absent.
    public static func extractPrefixedToken(prefix: String, from query: String) -> (remaining: String, value: String?) {
        let tokens = query.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard let match = tokens.first(where: { $0.lowercased().hasPrefix(prefix.lowercased()) }) else {
            return (query, nil)
        }
        let remaining = tokens.filter { $0.lowercased() != match.lowercased() }.joined(separator: " ")
        return (remaining, String(match.dropFirst(prefix.count)))
    }

    /// Builds a regex for each individual token that looks like one (`r:` prefix, or contains
    /// `*`/`^`/`$`), keyed by the token text — computed once per query and reused across every
    /// candidate file, instead of recompiling per file. Filter tokens (`date:`/`size:`/`kind:`/
    /// `ext:`/`tag:`) never reach `matchesTextOrRegex`, so they're skipped here.
    public static func parseTokenRegexes(query: String, caseSensitive: Bool) -> [String: NSRegularExpression] {
        let options: NSRegularExpression.Options = caseSensitive ? [] : [.caseInsensitive]
        var result: [String: NSRegularExpression] = [:]
        let tokens = query.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .whitespaces).filter { !$0.isEmpty }
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
        let tokens = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        var plainTextTokens: [String] = []
        for token in tokens {
            let lower = token.lowercased()
            if isFilterToken(lower) || lower == "hidden:true" {
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

    /// `scope` is the explicit Name/Content/Both menu choice — no implicit fallback. `tokenRegexes`
    /// comes from `parseTokenRegexes` — each token is matched against its own regex, if it has one,
    /// never the whole query string (mixing `kind:pdf` with an unrelated `r:`/wildcard token used to
    /// build one giant regex out of the entire query and silently match nothing).
    public static func matchesSearch(
        fileURL: URL, query: String, tokenRegexes: [String: NSRegularExpression], scope: SearchScope, caseSensitive: Bool) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }

        let tokens = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        let attributes = prefetchAttributes(for: fileURL, tokens: tokens, scope: scope)
        for token in tokens
            where !matchesToken(
                token: token, regex: tokenRegexes[token], scope: scope,
                caseSensitive: caseSensitive, attributes: attributes) {
            return false
        }
        return true
    }

    /// One `resourceValues` fetch covering every attribute the present tokens (and the content
    /// scope) can ask for — see `PrefetchedAttributes`. Returns empty values (all matchers then
    /// fail closed) when the file is gone or no token needs disk attributes.
    private static func prefetchAttributes(for fileURL: URL, tokens: [String], scope: SearchScope) -> PrefetchedAttributes {
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
        }
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
        token: String, regex: NSRegularExpression?, scope: SearchScope,
        caseSensitive: Bool, attributes: PrefetchedAttributes) -> Bool {
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
        return matchesTextOrRegex(
            token: token, regex: regex, scope: scope,
            caseSensitive: caseSensitive, attributes: attributes)
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
            // "Document" is a fuzzy user category with no single clean UTType — curated on purpose.
            return ["doc", "docx", "pdf", "pages", "txt", "md", "rtf", "odt", "xls", "xlsx"].contains(ext)
        case "code", "source":
            // "Code" spans source, scripts, and markup (JSON/HTML don't conform to .sourceCode) — curated.
            return ["swift", "py", "js", "ts", "json", "html", "css", "cpp", "c", "h", "sh", "yml", "yaml"].contains(ext)
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
        token: String, regex: NSRegularExpression?, scope: SearchScope,
        caseSensitive: Bool, attributes: PrefetchedAttributes) -> Bool {
        switch scope {
        case .name:
            matchesFileName(token: token, regex: regex, caseSensitive: caseSensitive, attributes: attributes)
        case .content:
            matchesContent(query: token, caseSensitive: caseSensitive, attributes: attributes)
        case .both:
            matchesFileName(token: token, regex: regex, caseSensitive: caseSensitive, attributes: attributes)
                || matchesContent(query: token, caseSensitive: caseSensitive, attributes: attributes)
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

    private static func matchesContent(query: String, caseSensitive: Bool, attributes: PrefetchedAttributes) -> Bool {
        guard query.count >= minContentQueryLength else { return false }
        let textExtensions: Set = ["txt", "md", "swift", "json", "py", "js", "ts", "css", "html", "sh", "yml", "xml", "csv"]
        guard textExtensions.contains(attributes.url.pathExtension.lowercased()) else { return false }
        guard let size = attributes.fileSize, size < 2_000_000 else { return false }
        guard let content = readTextContent(of: attributes.url) else { return false }
        return caseSensitive ? content.contains(query) : content.localizedCaseInsensitiveContains(query)
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
