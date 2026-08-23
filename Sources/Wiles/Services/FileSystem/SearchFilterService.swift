import Foundation

/// Parses and evaluates the search-bar query language (plain text, `r:` regex, and
/// `date:`/`size:`/`kind:`/`ext:`/`tag:` filter tokens) against candidate file URLs.
public struct SearchFilterService: Sendable {
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
        for token in tokens
            where !matchesToken(fileURL: fileURL, token: token, regex: tokenRegexes[token], scope: scope, caseSensitive: caseSensitive) {
            return false
        }
        return true
    }

    private static func matchesToken(fileURL: URL, token: String, regex: NSRegularExpression?, scope: SearchScope, caseSensitive: Bool) -> Bool {
        let lowerToken = token.lowercased()
        if lowerToken.hasPrefix("date:") {
            return matchesDateFilter(fileURL: fileURL, token: String(token.dropFirst(5)))
        } else if lowerToken.hasPrefix("size:") {
            return matchesSizeFilter(fileURL: fileURL, token: String(token.dropFirst(5)))
        } else if lowerToken.hasPrefix("kind:") || lowerToken.hasPrefix("ext:") {
            let prefix = lowerToken.hasPrefix("kind:") ? 5 : 4
            return matchesKindFilter(fileURL: fileURL, token: String(token.dropFirst(prefix)))
        } else if lowerToken.hasPrefix("tag:") {
            return matchesTagFilter(fileURL: fileURL, tag: String(token.dropFirst(4)))
        }
        return matchesTextOrRegex(fileURL: fileURL, token: token, regex: regex, scope: scope, caseSensitive: caseSensitive)
    }

    private static func matchesDateFilter(fileURL: URL, token: String) -> Bool {
        guard let modified = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) else {
            return false
        }
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

    private static func matchesSizeFilter(fileURL: URL, token: String) -> Bool {
        guard let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) else { return false }
        let (op, valueStr) = splitOperator(from: token.lowercased())

        let digits = valueStr.filter(\.isNumber)
        guard let num = Int64(digits), !digits.isEmpty else { return false }
        let unit = valueStr.filter(\.isLetter)
        let targetBytes = num * sizeFilterMultiplier(unit: unit)

        switch op {
        case "<": return size < targetBytes
        case "<=": return size <= targetBytes
        case "=": return size == targetBytes
        case ">": return size > targetBytes
        default: return size >= targetBytes
        }
    }

    private static func sizeFilterMultiplier(unit: String) -> Int64 {
        if unit.hasPrefix("k") {
            return 1024
        } else if unit.hasPrefix("b"), !unit.hasPrefix("by") {
            return 1
        } else if unit.hasPrefix("g") {
            return 1024 * 1024 * 1024
        }
        return 1024 * 1024
    }

    private static func matchesKindFilter(fileURL: URL, token: String) -> Bool {
        let lower = token.lowercased()
        let ext = fileURL.pathExtension.lowercased()

        switch lower {
        case "image", "img", "images":
            return ["png", "jpg", "jpeg", "gif", "svg", "webp", "heic", "tiff", "icns", "bmp"].contains(ext)
        case "doc", "document", "documents":
            return ["doc", "docx", "pdf", "pages", "txt", "md", "rtf", "odt", "xls", "xlsx"].contains(ext)
        case "code", "source":
            return ["swift", "py", "js", "ts", "json", "html", "css", "cpp", "c", "h", "sh", "yml", "yaml"].contains(ext)
        case "pdf":
            return ext == "pdf"
        case "folder", "dir", "directory":
            return (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        case "archive", "zip":
            return ["zip", "tar", "gz", "7z", "rar", "bz2"].contains(ext)
        default:
            return ext == lower || fileURL.lastPathComponent.lowercased().contains(lower)
        }
    }

    private static func matchesTagFilter(fileURL: URL, tag: String) -> Bool {
        let targetTag = tag.lowercased()
        guard let tags = try? (fileURL as NSURL).resourceValues(forKeys: [.tagNamesKey]),
              let tagArray = tags[.tagNamesKey] as? [String] else { return false }
        return tagArray.contains { $0.lowercased() == targetTag }
    }

    private static func matchesTextOrRegex(fileURL: URL, token: String, regex: NSRegularExpression?, scope: SearchScope, caseSensitive: Bool) -> Bool {
        switch scope {
        case .name:
            matchesFileName(fileURL: fileURL, token: token, regex: regex, caseSensitive: caseSensitive)
        case .content:
            matchesContent(fileURL: fileURL, query: token, caseSensitive: caseSensitive)
        case .both:
            matchesFileName(fileURL: fileURL, token: token, regex: regex, caseSensitive: caseSensitive)
                || matchesContent(fileURL: fileURL, query: token, caseSensitive: caseSensitive)
        }
    }

    private static func matchesFileName(fileURL: URL, token: String, regex: NSRegularExpression?, caseSensitive: Bool) -> Bool {
        let fileName = fileURL.lastPathComponent
        let nameMatches = caseSensitive ? fileName.contains(token) : fileName.localizedCaseInsensitiveContains(token)
        if nameMatches {
            return true
        }
        guard let regex else { return false }
        let range = NSRange(location: 0, length: fileName.utf16.count)
        return regex.firstMatch(in: fileName, options: [], range: range) != nil
    }

    private static func matchesContent(fileURL: URL, query: String, caseSensitive: Bool) -> Bool {
        guard query.count >= 3 else { return false }
        let textExtensions: Set = ["txt", "md", "swift", "json", "py", "js", "ts", "css", "html", "sh", "yml", "xml", "csv"]
        guard textExtensions.contains(fileURL.pathExtension.lowercased()) else { return false }
        guard let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize), size < 2_000_000 else { return false }
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return false }
        return caseSensitive ? content.contains(query) : content.localizedCaseInsensitiveContains(query)
    }
}
