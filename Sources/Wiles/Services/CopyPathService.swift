import AppKit
import Foundation

public final class CopyPathService: Sendable {
    @MainActor
    public static func copy(urls: [URL], variant: PathCopyVariant, relativeTo base: URL? = nil) {
        guard !urls.isEmpty else { return }
        let formattedPaths = urls.map { format(url: $0, variant: variant, relativeTo: base) }
        let combined = formattedPaths.joined(separator: "\n")

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(combined, forType: .string)
    }

    public static func format(url: URL, variant: PathCopyVariant, relativeTo base: URL? = nil) -> String {
        switch variant {
        case .absolute:
            url.standardizedFileURL.path
        case .relative:
            relativePath(of: url, relativeTo: base)
        case .fileURL:
            url.standardizedFileURL.absoluteString
        case .terminalEscaped:
            escapeForTerminal(url.standardizedFileURL.path)
        }
    }

    public static func relativePath(of url: URL, relativeTo base: URL?) -> String {
        guard let base else { return url.standardizedFileURL.path }
        let targetPath = url.standardizedFileURL.path
        let basePath = base.standardizedFileURL.path
        if targetPath == basePath {
            return "."
        }
        let prefix = basePath.hasSuffix("/") ? basePath : basePath + "/"
        if targetPath.hasPrefix(prefix) {
            return String(targetPath.dropFirst(prefix.count))
        }
        return targetPath
    }

    /// Backslash-escapes shell metacharacters for use as an **unquoted** token (the "copy path,
    /// terminal-escaped" menu item). Do not also wrap the result in quotes — use
    /// `posixSingleQuoted` for that case instead.
    public static func escapeForTerminal(_ path: String) -> String {
        let specialChars = ["\\", " ", "\t", "(", ")", "[", "]", "{", "}", "'", "\"", "&", "$", "|", ";", "*", "?", "<", ">", "#", "!", "`"]
        return specialChars.reduce(path) { result, char in
            result.replacingOccurrences(of: char, with: "\\" + char)
        }
    }

    /// Wraps a raw string in POSIX single quotes, so every character inside is literal. The only
    /// escaping needed is for an embedded `'`, closed and reopened as `'\''`. Use this when the
    /// value goes into a quoted position (e.g. `cd '<path>'`), never `escapeForTerminal`.
    public static func posixSingleQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
