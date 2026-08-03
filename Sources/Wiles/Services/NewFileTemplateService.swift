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

public struct NewFileTemplateService: Sendable {
    public static func createTemplateFile(
        in folderURL: URL,
        fileName: String,
        template: FileTemplate
    ) throws -> URL {
        let trimmed = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? template.defaultFileName : trimmed

        var targetURL = folderURL.appendingPathComponent(finalName)
        if !targetURL.pathExtension.isEmpty == false {
            targetURL = targetURL.appendingPathExtension(template.rawValue)
        }

        let uniqueURL = generateUniqueURL(for: targetURL)
        let contentData = template.initialContent.data(using: .utf8) ?? Data()
        try contentData.write(to: uniqueURL, options: .atomic)
        return uniqueURL
    }

    private static func generateUniqueURL(for originalURL: URL) -> URL {
        let fm = FileManager.default
        guard fm.fileExists(atPath: originalURL.path) else { return originalURL }

        let folder = originalURL.deletingLastPathComponent()
        let ext = originalURL.pathExtension
        let baseName = originalURL.deletingPathExtension().lastPathComponent

        var counter = 2
        var candidateURL: URL
        repeat {
            let newName = ext.isEmpty ? "\(baseName) \(counter)" : "\(baseName) \(counter).\(ext)"
            candidateURL = folder.appendingPathComponent(newName)
            counter += 1
        } while fm.fileExists(atPath: candidateURL.path)

        return candidateURL
    }
}
