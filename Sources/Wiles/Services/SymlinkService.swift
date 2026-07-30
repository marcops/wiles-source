import Foundation

public enum SymlinkMode: String, CaseIterable, Identifiable, Sendable {
    case absolute = "Absolute"
    case relative = "Relative"
    public var id: String { rawValue }
}

public struct SymlinkService: Sendable {
    public static func createSymlink(
        targetURL: URL,
        destinationFolder: URL,
        symlinkName: String,
        mode: SymlinkMode
    ) throws -> URL {
        let fm = FileManager.default
        let trimmed = symlinkName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? targetURL.lastPathComponent + " link" : trimmed
        
        let destinationURL = destinationFolder.appendingPathComponent(name)
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
        while commonIndex < originComponents.count && commonIndex < targetComponents.count && originComponents[commonIndex] == targetComponents[commonIndex] {
            commonIndex += 1
        }
        
        var relativeComponents: [String] = []
        let upCount = originComponents.count - commonIndex
        for _ in 0..<upCount {
            relativeComponents.append("..")
        }
        
        relativeComponents.append(contentsOf: targetComponents[commonIndex...])
        return relativeComponents.joined(separator: "/")
    }
}
