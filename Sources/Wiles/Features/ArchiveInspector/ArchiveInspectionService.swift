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

@MainActor
public protocol ArchiveInspectionServiceProtocol: Sendable {
    static func listEntries(in archiveURL: URL) -> [ArchiveEntryItem]
    static func extractSingleEntry(from archiveURL: URL, entryPath: String, to destinationFolder: URL) throws -> URL
}

public final class ArchiveInspectionService: ArchiveInspectionServiceProtocol, Sendable {
    @MainActor
    public static func listEntries(in archiveURL: URL) -> [ArchiveEntryItem] {
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
    }

    @MainActor
    public static func extractSingleEntry(from archiveURL: URL, entryPath: String, to destinationFolder: URL) throws -> URL {
        let entryName = (entryPath as NSString).lastPathComponent
        let destURL = destinationFolder.appendingPathComponent(entryName)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-p", archiveURL.path, entryPath]

        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()

        let fileData = pipe.fileHandleForReading.readDataToEndOfFile()
        try fileData.write(to: destURL)
        return destURL
    }
}
