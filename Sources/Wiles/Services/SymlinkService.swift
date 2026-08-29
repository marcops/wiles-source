import Foundation

public struct SymlinkService: Sendable {
    public static func createSymlink(
        targetURL: URL,
        destinationFolder: URL,
        symlinkName: String,
        mode: SymlinkMode) throws -> URL {
        let fm = FileManager.default
        let trimmed = symlinkName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? targetURL.lastPathComponent + " link" : trimmed

        let destinationURL = destinationFolder.appendingPathComponent(name)

        // If the destination resolves to the exact same path as the target, bail before touching
        // anything (see DEV_RULES.md "Never Destroy User Data" / FileSystemService.moveItem).
        guard destinationURL.standardizedFileURL != targetURL.standardizedFileURL else {
            throw WilesError.localized(key: .symlinkCannotReplaceOwnTarget, arguments: [])
        }

        // Never delete what's already at the destination "to make room" — a failed
        // createSymbolicLink afterwards would leave the user with neither. Fail loud instead and
        // let the sheet ask for a different name.
        guard !fm.fileExists(atPath: destinationURL.path) else {
            throw WilesError.destinationExists(name: name)
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
