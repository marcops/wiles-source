import Foundation

public enum FileTemplate: String, CaseIterable, Identifiable, Sendable {
    case text = "txt"
    case markdown = "md"
    case swift
    case json
    case python = "py"

    public var id: String {
        rawValue
    }

    public var defaultFileName: String {
        switch self {
        case .text: "Document.txt"
        case .markdown: "README.md"
        case .swift: "File.swift"
        case .json: "data.json"
        case .python: "script.py"
        }
    }

    public var initialContent: String {
        switch self {
        case .text: ""
        case .markdown: "# Title\n\nContent goes here.\n"
        case .swift: "import Foundation\n\n"
        case .json: "{\n  \"key\": \"value\"\n}\n"
        case .python: "#!/usr/bin/env python3\n\n"
        }
    }
}
