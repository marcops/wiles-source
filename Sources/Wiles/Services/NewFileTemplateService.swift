import Foundation

public enum NewFileTemplateService: Sendable {
    /// Placeholder name for a new blank text file — the user is dropped into inline rename right after.
    static let defaultFileName = "Document.txt"

    /// Creates an empty text file in `folderURL`, `" 2"`-suffixed on collision. (Replaced the
    /// speculative `FileTemplate`/`fileName`/`language` API whose one caller always passed `""`/`.text`.)
    public static func createTextFile(in folderURL: URL) throws -> URL {
        let targetURL = folderURL.appendingPathComponent(defaultFileName)
        let uniqueURL = UniqueFileNaming.uniqueURL(for: targetURL, in: folderURL, isDirectory: false)
        try Data().write(to: uniqueURL, options: .atomic)
        return uniqueURL
    }
}
