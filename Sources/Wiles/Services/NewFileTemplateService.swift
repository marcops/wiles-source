import Foundation

public struct NewFileTemplateService: Sendable {
    public static func createTemplateFile(
        in folderURL: URL,
        fileName: String,
        template: FileTemplate,
        language: AppLanguage = .system) throws -> URL {
        let trimmed = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? template.defaultFileName : trimmed

        var targetURL = folderURL.appendingPathComponent(finalName)
        if targetURL.pathExtension.isEmpty {
            targetURL = targetURL.appendingPathExtension(template.rawValue)
        }

        let uniqueURL = UniqueFileNaming.uniqueURL(for: targetURL, in: folderURL, isDirectory: false)
        let contentData = template.initialContent(language: language).data(using: .utf8) ?? Data()
        try contentData.write(to: uniqueURL, options: .atomic)
        return uniqueURL
    }
}
