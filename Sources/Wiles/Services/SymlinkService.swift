import Foundation

public struct SymlinkService: SymlinkServiceProtocol, Sendable {
    public static func createSymlink(
        targetURL: URL,
        destinationFolder: URL,
        symlinkName: String,
        mode: SymlinkMode) throws -> URL {
        let fm = FileManager.default
        let trimmed = symlinkName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? targetURL.lastPathComponent + " link" : trimmed

        let destinationURL = destinationFolder.appendingPathComponent(name)

        // If the destination resolves to the exact same path as the target (creating a symlink in
        // the target's own folder using the target's own filename), the "remove existing
        // destination before creating the symlink" branch below would delete destinationURL —
        // which IS the target — before createSymbolicLink ever runs, permanently destroying the
        // real file and then failing anyway because the target no longer exists. Must check this
        // before touching the filesystem at all, not after (see rule 35 / FileSystemService.moveItem).
        guard destinationURL.standardizedFileURL != targetURL.standardizedFileURL else {
            throw WilesError.operationFailed(reason: "Cannot create a symlink that would replace its own target.")
        }

        if fm.fileExists(atPath: destinationURL.path) {
            try fm.removeItem(at: destinationURL)
        }

        if mode == .absolute {
            try fm.createSymbolicLink(at: destinationURL, withDestinationURL: targetURL)
        } else {
            let relativePath = computeRelativePath(from: destinationFolder, to: targetURL)
            try fm.createSymbolicLink(atPath: destinationURL.path, withDestinationPath: relativePath)
        }

        return destinationURL
    }

    private static func computeRelativePath(from originFolder: URL, to targetURL: URL) -> String {
        let originComponents = originFolder.standardizedFileURL.pathComponents
        let targetComponents = targetURL.standardizedFileURL.pathComponents

        var commonIndex = 0
        while commonIndex < originComponents.count, commonIndex < targetComponents.count, originComponents[commonIndex] == targetComponents[commonIndex] {
            commonIndex += 1
        }

        var relativeComponents: [String] = []
        let upCount = originComponents.count - commonIndex
        for _ in 0 ..< upCount {
            relativeComponents.append("..")
        }

        relativeComponents.append(contentsOf: targetComponents[commonIndex...])
        return relativeComponents.joined(separator: "/")
    }
}
