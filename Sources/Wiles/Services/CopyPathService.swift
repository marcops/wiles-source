import Foundation
import AppKit

public enum PathCopyVariant: String, CaseIterable, Sendable {
    case absolute
    case relative
    case fileURL
    case terminalEscaped
}

@MainActor
public protocol CopyPathServiceProtocol: Sendable {
    static func copy(urls: [URL], variant: PathCopyVariant, relativeTo base: URL?)
}

public final class CopyPathService: CopyPathServiceProtocol, Sendable {
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
            return url.standardizedFileURL.path
        case .relative:
            return relativePath(of: url, relativeTo: base)
        case .fileURL:
            return url.standardizedFileURL.absoluteString
        case .terminalEscaped:
            return escapeForTerminal(url.standardizedFileURL.path)
        }
    }

    public static func relativePath(of url: URL, relativeTo base: URL?) -> String {
        guard let base = base else { return url.standardizedFileURL.path }
        let targetPath = url.standardizedFileURL.path
        let basePath = base.standardizedFileURL.path
        if targetPath == basePath { return "." }
        let prefix = basePath.hasSuffix("/") ? basePath : basePath + "/"
        if targetPath.hasPrefix(prefix) {
            return String(targetPath.dropFirst(prefix.count))
        }
        return targetPath
    }

    public static func escapeForTerminal(_ path: String) -> String {
        let specialChars = ["\\", " ", "\t", "(", ")", "[", "]", "{", "}", "'", "\"", "&", "$", "|", ";", "*", "?", "<", ">", "#", "!", "`"]
        var result = path
        for char in specialChars {
            result = result.replacingOccurrences(of: char, with: "\\" + char)
        }
        return result
    }
}
