import Foundation

public enum FileTemplate: String, CaseIterable, Identifiable, Sendable {
    case text = "txt"
    case markdown = "md"
    case swift = "swift"
    case json = "json"
    case python = "py"

    public var id: String { rawValue }

    public var defaultFileName: String {
        switch self {
        case .text: return "Document.txt"
        case .markdown: return "README.md"
        case .swift: return "File.swift"
        case .json: return "data.json"
        case .python: return "script.py"
        }
    }

    public var initialContent: String {
        switch self {
        case .text: return ""
        case .markdown: return "# Title\n\nContent goes here.\n"
        case .swift: return "import Foundation\n\n"
        case .json: return "{\n  \"key\": \"value\"\n}\n"
        case .python: return "#!/usr/bin/env python3\n\n"
        }
    }
}
