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
            posixSingleQuoted(url.standardizedFileURL.path)
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

    /// Wraps a raw string in POSIX single quotes, so every character inside is literal — including
    /// `~`, spaces, and embedded newlines that a backslash-escaped unquoted token can't represent.
    /// The only escaping needed is an embedded `'`, closed and reopened as `'\''`. Backs both the
    /// integrated terminal's `cd '<path>'` and the "copy path, terminal-escaped" menu item.
    public static func posixSingleQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
