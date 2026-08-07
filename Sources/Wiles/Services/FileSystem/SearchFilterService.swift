import Foundation

/// Parses and evaluates the search-bar query language (plain text, `r:` regex, and
/// `date:`/`size:`/`kind:`/`ext:`/`tag:` filter tokens) against candidate file URLs.
public struct SearchFilterService: Sendable {
    public static func parseSearchRegex(query: String) -> NSRegularExpression? {
        guard !query.isEmpty else { return nil }
        let pattern: String
        if query.hasPrefix("r:") {
            pattern = String(query.dropFirst(2))
        } else if query.contains("*") || query.contains("^") || query.contains("$") {
            pattern = query
        } else {
            return nil
        }
        return try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }

    public static func matchesSearch(fileURL: URL, query: String, regex: NSRegularExpression?) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }

        let tokens = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        for token in tokens where !matchesToken(fileURL: fileURL, token: token, regex: regex) {
            return false
        }
        return true
    }

    private static func matchesToken(fileURL: URL, token: String, regex: NSRegularExpression?) -> Bool {
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
        return matchesTextOrRegex(fileURL: fileURL, token: token, regex: regex)
    }

    private static func matchesDateFilter(fileURL: URL, token: String) -> Bool {
        guard let modified = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) else {
            return false
        }
        let lower = token.lowercased()
        if lower == "today" { return Calendar.current.isDateInToday(modified) }
        if lower == "yesterday" { return Calendar.current.isDateInYesterday(modified) }

        let (op, valueStr) = splitOperator(from: lower)
        guard let num = Int(valueStr.compactMap { $0.isNumber ? $0 : nil }.map(String.init).joined()) else { return false }
        let unit = valueStr.filter { $0.isLetter }
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
        case "h": return Double(num) * 3600
        case "w": return Double(num) * 7 * 86400
        case "m": return Double(num) * 30 * 86400
        case "y": return Double(num) * 365 * 86400
        default: return Double(num) * 86400
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
        } else if valueStr.hasPrefix(">") || valueStr.hasPrefix("<") || valueStr.hasPrefix("=") {
            op = String(valueStr.prefix(1))
            valueStr = String(valueStr.dropFirst(1))
        }
        return (op, valueStr)
    }

    private static func matchesSizeFilter(fileURL: URL, token: String) -> Bool {
        guard let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) else { return false }
        let (op, valueStr) = splitOperator(from: token.lowercased())

        let digits = valueStr.filter { $0.isNumber }
        guard let num = Int64(digits), !digits.isEmpty else { return false }
        let unit = valueStr.filter { $0.isLetter }
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
        } else if unit.hasPrefix("b") && !unit.hasPrefix("by") {
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
            return (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
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

    private static func matchesTextOrRegex(fileURL: URL, token: String, regex: NSRegularExpression?) -> Bool {
        let fileName = fileURL.lastPathComponent
        if fileName.localizedCaseInsensitiveContains(token) { return true }
        if let regex = regex {
            let range = NSRange(location: 0, length: fileName.utf16.count)
            if regex.firstMatch(in: fileName, options: [], range: range) != nil { return true }
        }
        return matchesContent(fileURL: fileURL, query: token)
    }

    private static func matchesContent(fileURL: URL, query: String) -> Bool {
        guard query.count >= 3 else { return false }
        let textExtensions: Set<String> = ["txt", "md", "swift", "json", "py", "js", "ts", "css", "html", "sh", "yml", "xml", "csv"]
        guard textExtensions.contains(fileURL.pathExtension.lowercased()) else { return false }
        guard let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize), size < 2_000_000 else { return false }
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return false }
        return content.localizedCaseInsensitiveContains(query)
    }
}
