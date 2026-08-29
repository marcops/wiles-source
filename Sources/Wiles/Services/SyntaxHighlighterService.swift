import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

public enum SyntaxHighlighterService: Sendable {
    private static let maxHighlightChars = 10_000
    private static let highlightFontSize: CGFloat = 11

    public static func highlightCode(content: String, fileExtension: String, language: AppLanguage) async -> AttributedString {
        await Task.detached(priority: .userInitiated) {
            buildHighlighted(content: content, fileExtension: fileExtension, language: language)
        }.value
    }

    private static func buildHighlighted(content: String, fileExtension: String, language: AppLanguage) -> AttributedString {
        let truncatedContent = content.utf16.count > maxHighlightChars
            ? String(content.prefix(maxHighlightChars)) + L10n.string(.syntaxTruncatedNotice, lang: language)
            : content

        var attributed = AttributedString(truncatedContent)
        attributed.font = Font.system(size: highlightFontSize, design: .monospaced)
        attributed.foregroundColor = NSColor.textColor

        guard let highlightLanguage = HighlightLanguage(fileExtension: fileExtension) else {
            return attributed
        }

        if let keywordsRegex = keywordRegexByLanguage[highlightLanguage] {
            applyColor(regex: keywordsRegex, color: .systemPink, in: &attributed, content: truncatedContent)
        }
        applyColor(regex: Self.stringsRegex, color: .systemOrange, in: &attributed, content: truncatedContent)
        if highlightLanguage.usesSlashComments {
            applyColor(regex: Self.slashCommentRegex, color: .systemGreen, in: &attributed, content: truncatedContent)
        }
        if highlightLanguage.usesHashComments {
            applyColor(regex: Self.hashCommentRegex, color: .systemGreen, in: &attributed, content: truncatedContent)
        }

        return attributed
    }

    /// Language detected from a file extension, mapped through `UTType` where a specific extension
    /// isn't listed. Each case carries its own keyword set so `func` isn't coloured in a Python file.
    enum HighlightLanguage: CaseIterable {
        case swift
        case python
        case javascript
        case kotlin
        case json
        case shell
        case css
        case markup
        case yaml
        case markdown
        case genericSource

        init?(fileExtension: String) {
            switch fileExtension.lowercased() {
            case "swift": self = .swift
            case "py", "pyw", "pyi": self = .python
            case "js", "mjs", "cjs", "jsx", "ts", "tsx": self = .javascript
            case "kt", "kts": self = .kotlin
            case "json": self = .json
            case "sh", "bash", "zsh", "command": self = .shell
            case "css", "scss", "less": self = .css
            case "html", "htm", "xml", "plist": self = .markup
            case "yml", "yaml": self = .yaml
            case "md", "markdown": self = .markdown
            default:
                guard let mapped = Self(uttypeForExtension: fileExtension) else { return nil }
                self = mapped
            }
        }

        private init?(uttypeForExtension fileExtension: String) {
            guard let type = UTType(filenameExtension: fileExtension.lowercased()) else { return nil }
            // Ordered most-specific first: Swift/shell also conform to `.sourceCode`, so it stays last.
            guard let match = Self.uttypeConformances.first(where: { type.conforms(to: $0.type) }) else { return nil }
            self = match.language
        }

        private static let uttypeConformances: [(type: UTType, language: HighlightLanguage)] = [
            (.json, .json),
            (.yaml, .yaml),
            (.propertyList, .markup),
            (.xml, .markup),
            (.html, .markup),
            (.shellScript, .shell),
            (.swiftSource, .swift),
            (.sourceCode, .genericSource)
        ]

        var keywords: [String] {
            switch self {
            case .swift:
                ["func", "var", "let", "class", "struct", "enum", "protocol", "extension", "import",
                 "return", "if", "else", "for", "in", "while", "guard", "public", "private", "self",
                 "true", "false", "nil"]
            case .python:
                ["def", "class", "import", "from", "as", "return", "if", "elif", "else", "for", "in",
                 "while", "with", "pass", "lambda", "yield", "self", "True", "False", "None"]
            case .javascript:
                ["function", "const", "let", "var", "class", "return", "if", "else", "for", "in", "of",
                 "while", "import", "export", "from", "async", "await", "true", "false", "null", "undefined"]
            case .kotlin:
                ["fun", "val", "var", "class", "object", "interface", "import", "return", "if", "else",
                 "for", "in", "while", "when", "public", "private", "internal", "true", "false", "null"]
            case .json, .shell, .css, .markup, .yaml, .markdown, .genericSource:
                []
            }
        }

        var usesSlashComments: Bool {
            switch self {
            case .swift, .javascript, .kotlin, .css, .genericSource: true
            case .python, .json, .shell, .markup, .yaml, .markdown: false
            }
        }

        var usesHashComments: Bool {
            switch self {
            case .python, .shell, .yaml: true
            case .swift, .javascript, .kotlin, .json, .css, .markup, .markdown, .genericSource: false
            }
        }
    }

    /// Compiled once and reused across every highlight call: one alternation pass over a language's
    /// keywords instead of a separate `NSRegularExpression` scan per keyword.
    private static let keywordRegexByLanguage: [HighlightLanguage: NSRegularExpression] = {
        var map: [HighlightLanguage: NSRegularExpression] = [:]
        for language in HighlightLanguage.allCases where !language.keywords.isEmpty {
            if let regex = try? NSRegularExpression(
                pattern: "\\b(\(language.keywords.joined(separator: "|")))\\b", options: [.anchorsMatchLines]) {
                map[language] = regex
            }
        }
        return map
    }()

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
