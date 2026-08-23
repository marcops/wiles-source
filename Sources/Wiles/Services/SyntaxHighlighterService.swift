import AppKit
import Foundation
import SwiftUI

public struct SyntaxHighlighterService: Sendable {
    public static func highlightCode(content: String, fileExtension: String, language: AppLanguage) -> AttributedString {
        let maxChars = 10000
        let truncatedContent = content.count > maxChars ? String(content.prefix(maxChars)) + L10n.string(.syntaxTruncatedNotice, lang: language) : content

        var attributed = AttributedString(truncatedContent)
        attributed.font = Font.system(size: 11, design: .monospaced)
        attributed.foregroundColor = NSColor.textColor

        let ext = fileExtension.lowercased()
        guard ["swift", "json", "py", "js", "ts", "css", "html", "sh", "yml", "md"].contains(ext) else {
            return attributed
        }

        applyColor(regex: Self.keywordsRegex, color: .systemPink, in: &attributed, content: truncatedContent)
        applyColor(regex: Self.stringsRegex, color: .systemOrange, in: &attributed, content: truncatedContent)
        applyColor(regex: Self.slashCommentRegex, color: .systemGreen, in: &attributed, content: truncatedContent)
        applyColor(regex: Self.hashCommentRegex, color: .systemGreen, in: &attributed, content: truncatedContent)

        return attributed
    }

    private static let keywords = [
        "func", "var", "let", "class", "struct", "import", "return", "if", "else", "for", "in",
        "while", "guard", "public", "private", "true", "false", "def", "self", "function", "const"
    ]

    /// Compiled once and reused across every highlight call: one alternation pass over all
    /// keywords instead of a separate NSRegularExpression scan per keyword.
    private static let keywordsRegex = try? NSRegularExpression(
        pattern: "\\b(\(keywords.joined(separator: "|")))\\b", options: [.anchorsMatchLines])
    private static let stringsRegex = try? NSRegularExpression(pattern: "\"[^\"]*\"", options: [.anchorsMatchLines])
    private static let slashCommentRegex = try? NSRegularExpression(pattern: "//.*$", options: [.anchorsMatchLines])
    private static let hashCommentRegex = try? NSRegularExpression(pattern: "#.*$", options: [.anchorsMatchLines])

    private static func applyColor(regex: NSRegularExpression?, color: NSColor, in attributed: inout AttributedString, content: String) {
        guard let regex else { return }
        let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: content.utf16.count))
        for match in matches {
            if let range = Range(match.range, in: content),
               let attrRange = Range(range, in: attributed) {
                attributed[attrRange].foregroundColor = color
            }
        }
    }
}
