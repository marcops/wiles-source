import Foundation
import AppKit
import SwiftUI

public struct SyntaxHighlighterService: Sendable {
    public static func highlightCode(content: String, fileExtension: String) -> AttributedString {
        let maxChars = 10_000
        let truncatedContent = content.count > maxChars ? String(content.prefix(maxChars)) + "\n... (truncated)" : content

        var attributed = AttributedString(truncatedContent)
        attributed.font = Font.system(size: 11, design: .monospaced)
        attributed.foregroundColor = NSColor.textColor

        let ext = fileExtension.lowercased()
        guard ["swift", "json", "py", "js", "ts", "css", "html", "sh", "yml", "md"].contains(ext) else {
            return attributed
        }

        highlightKeywords(in: &attributed, content: truncatedContent)
        highlightStrings(in: &attributed, content: truncatedContent)
        highlightComments(in: &attributed, content: truncatedContent)

        return attributed
    }

    private static func highlightKeywords(in attributed: inout AttributedString, content: String) {
        let keywords = [
            "func", "var", "let", "class", "struct", "import", "return", "if", "else", "for", "in",
            "while", "guard", "public", "private", "true", "false", "def", "self", "function", "const"
        ]
        for kw in keywords {
            let pattern = "\\b\(kw)\\b"
            applyColor(pattern: pattern, color: .systemPink, in: &attributed, content: content)
        }
    }

    private static func highlightStrings(in attributed: inout AttributedString, content: String) {
        applyColor(pattern: "\"[^\"]*\"", color: .systemOrange, in: &attributed, content: content)
    }

    private static func highlightComments(in attributed: inout AttributedString, content: String) {
        applyColor(pattern: "//.*$", color: .systemGreen, in: &attributed, content: content)
        applyColor(pattern: "#.*$", color: .systemGreen, in: &attributed, content: content)
    }

    private static func applyColor(pattern: String, color: NSColor, in attributed: inout AttributedString, content: String) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return }
        let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: content.utf16.count))
        for match in matches {
            if let range = Range(match.range, in: content),
               let attrRange = Range(range, in: attributed) {
                attributed[attrRange].foregroundColor = color
            }
        }
    }
}
