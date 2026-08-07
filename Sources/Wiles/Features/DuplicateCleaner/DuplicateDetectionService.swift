import Foundation
import AppKit
import CryptoKit

public final class DuplicateDetectionService: Sendable {
    public static let shared = DuplicateDetectionService()

    private init() {}

    public func findDuplicates(in folderURL: URL) async -> DuplicateScanResult {
        return await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            guard let enumerator = fm.enumerator(
                at: folderURL,
                includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else {
                return DuplicateScanResult(groups: [], totalReclaimableBytes: 0)
            }

            var sizeMap: [Int64: [URL]] = [:]

            while let fileURL = enumerator.nextObject() as? URL {
                guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
                      let isDir = resourceValues.isDirectory, !isDir,
                      let size = resourceValues.fileSize, size > 0 else {
                    continue
                }
                sizeMap[Int64(size), default: []].append(fileURL)
            }

            let candidateGroups = sizeMap.filter { $0.value.count > 1 }
            var finalGroups: [DuplicateGroup] = []
            var totalReclaimable: Int64 = 0

            for (size, urls) in candidateGroups {
                let (groups, reclaimable) = Self.confirmedDuplicateGroups(among: urls, size: size)
                finalGroups.append(contentsOf: groups)
                totalReclaimable += reclaimable
            }

            return DuplicateScanResult(groups: finalGroups, totalReclaimableBytes: totalReclaimable)
        }.value
    }

    /// Same-size candidates with a matching *partial* (first-4KB) hash are not yet proven
    /// duplicates — many formats (MP4, ISO, DMG, VM images) share fixed headers, so two files
    /// this size and this partial hash could still differ entirely past the first 4KB. Only a
    /// full-content hash, computed here for partial-hash matches only (not every candidate, to
    /// avoid hashing every same-size file in full), can safely group files as true duplicates.
    private static func confirmedDuplicateGroups(among urls: [URL], size: Int64) -> ([DuplicateGroup], Int64) {
        var partialHashGroups: [String: [URL]] = [:]
        for url in urls {
            if let hash = Self.computePartialHash(for: url) {
                partialHashGroups[hash, default: []].append(url)
            }
        }

        var groups: [DuplicateGroup] = []
        var reclaimable: Int64 = 0
        for (_, candidates) in partialHashGroups where candidates.count > 1 {
            var fullHashGroups: [String: [URL]] = [:]
            for url in candidates {
                if let fullHash = Self.computeFullHash(for: url) {
                    fullHashGroups[fullHash, default: []].append(url)
                }
            }
            for (fullHashKey, matchedURLs) in fullHashGroups where matchedURLs.count > 1 {
                let fileItems = matchedURLs.map { FileItem(url: $0, icon: NSWorkspace.shared.icon(forFile: $0.path)) }
                let group = DuplicateGroup(hash: fullHashKey, fileSize: size, items: fileItems)
                groups.append(group)
                reclaimable += group.reclaimableBytes
            }
        }
        return (groups, reclaimable)
    }

    private static func computePartialHash(for url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        let sampleData = (try? handle.read(upToCount: 4096)) ?? Data()
        guard !sampleData.isEmpty else { return nil }

        let digest = SHA256.hash(data: sampleData)
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }

    /// Reads in fixed-size chunks via FileHandle rather than Data(contentsOf:) so hashing a
    /// multi-gigabyte file never loads the whole thing into RAM at once.
    private static func computeFullHash(for url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        var hasher = SHA256()
        let chunkSize = 1024 * 1024 // 1 MB
        while let chunk = try? handle.read(upToCount: chunkSize), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        let digest = hasher.finalize()
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}
