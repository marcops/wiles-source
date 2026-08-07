import Foundation
import AppKit

public struct ArchiveEntryItem: Identifiable, Sendable {
    public var id: String { path }
    public let path: String
    public let isDirectory: Bool
    public let name: String

    public init(path: String) {
        self.path = path
        self.isDirectory = path.hasSuffix("/")
        let clean = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.name = (clean as NSString).lastPathComponent
    }
}

public protocol ArchiveInspectionServiceProtocol: Sendable {
    static func listEntries(in archiveURL: URL) async -> [ArchiveEntryItem]
    static func extractSingleEntry(from archiveURL: URL, entryPath: String, to destinationFolder: URL) async throws -> URL
}

public final class ArchiveInspectionService: ArchiveInspectionServiceProtocol, Sendable {
    public static func listEntries(in archiveURL: URL) async -> [ArchiveEntryItem] {
        return await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-Z1", archiveURL.path]

            let pipe = Pipe()
            process.standardOutput = pipe
            try? process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return [] }

            let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
            return lines.map { ArchiveEntryItem(path: $0) }
        }.value
    }

    public static func extractSingleEntry(from archiveURL: URL, entryPath: String, to destinationFolder: URL) async throws -> URL {
        return try await Task.detached(priority: .userInitiated) {
            let entryName = (entryPath as NSString).lastPathComponent
            let destURL = destinationFolder.appendingPathComponent(entryName)

            // Creating the file beforehand so FileHandle can write to it
            FileManager.default.createFile(atPath: destURL.path, contents: nil, attributes: nil)
            guard let fileHandle = try? FileHandle(forWritingTo: destURL) else {
                throw NSError(domain: "ArchiveInspectionService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create destination file."])
            }
            defer { try? fileHandle.close() }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-p", archiveURL.path, entryPath]

            // Direct standardOutput directly into the FileHandle.
            // The OS streams the unzipped bytes straight to disk, never accumulating them in RAM.
            // This prevents an immediate Out-Of-Memory (OOM) crash when extracting massive files.
            process.standardOutput = fileHandle
            
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus != 0 {
                try? FileManager.default.removeItem(at: destURL)
                throw NSError(domain: "ArchiveInspectionService", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Extraction process failed."])
            }

            return destURL
        }.value
    }
}
