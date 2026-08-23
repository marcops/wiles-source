import Foundation

/// Canonical "find the next free name" utility, replacing 5 near-duplicate ad-hoc implementations
/// (`ArchiveService.uniqueZipDestination`, `FileSystemService+Actions.uniqueDestination` and
/// `createUniqueDirectory`, `NewFileTemplateService.generateUniqueURL`,
/// `PDFMergeService.uniqueDestination`) that each reimplemented the same
/// `while/repeat fileExists(...) { counter += 1 }` loop with inconsistent separators/starting
/// counters (some produced `name_1.ext`, others `name 2`). Standardizes on Finder's own convention:
/// separator is a space, and the first duplicate is " 2" (not " 1" or "_1"), e.g.
/// `"Document.txt"` -> `"Document 2.txt"` -> `"Document 3.txt"`, and for directories
/// `"Untitled Folder"` -> `"Untitled Folder 2"`.
public enum UniqueFileNaming {
    /// Returns `baseURL` unchanged if nothing exists at that path yet inside `directory`;
    /// otherwise appends " 2", " 3", ... (before the extension for files, after the full name for
    /// directories) until it finds a path that doesn't exist.
    ///
    /// - Parameters:
    ///   - baseURL: The originally-desired URL (e.g. `folder/Document.txt` or
    ///     `parent/Untitled Folder`) used to derive the base name and, for files, the extension.
    ///   - directory: The folder candidates are generated in. Callers pass `baseURL`'s own parent
    ///     folder in every current call site, but it's taken explicitly so callers that already
    ///     have the directory handy don't need to round-trip through `deletingLastPathComponent()`.
    ///   - isDirectory: When `true`, the whole `lastPathComponent` of `baseURL` is treated as the
    ///     name (no extension splitting) so a folder named e.g. "My.Files" isn't mis-split.
    ///   - fileManager: Injectable for testability; defaults to `.default`.
    public static func uniqueURL(
        for baseURL: URL,
        in directory: URL,
        isDirectory: Bool,
        using fileManager: FileManager = .default) -> URL {
        guard fileManager.fileExists(atPath: baseURL.path) else { return baseURL }

        let ext = isDirectory ? "" : baseURL.pathExtension
        let baseName = isDirectory
            ? baseURL.lastPathComponent
            : baseURL.deletingPathExtension().lastPathComponent

        var counter = 2
        var candidate: URL
        repeat {
            let candidateName = ext.isEmpty ? "\(baseName) \(counter)" : "\(baseName) \(counter).\(ext)"
            candidate = directory.appendingPathComponent(candidateName)
            counter += 1
        } while fileManager.fileExists(atPath: candidate.path)

        return candidate
    }
}
