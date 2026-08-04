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
                var hashGroups: [String: [URL]] = [:]
                for url in urls {
                    if let hash = Self.computePartialHash(for: url) {
                        hashGroups[hash, default: []].append(url)
                    }
                }

                for (hashKey, matchedURLs) in hashGroups where matchedURLs.count > 1 {
                    let fileItems = matchedURLs.map { FileItem(url: $0, icon: NSWorkspace.shared.icon(forFile: $0.path)) }
                    if fileItems.count > 1 {
                        let group = DuplicateGroup(hash: hashKey, fileSize: size, items: fileItems)
                        finalGroups.append(group)
                        totalReclaimable += group.reclaimableBytes
                    }
                }
            }

            return DuplicateScanResult(groups: finalGroups, totalReclaimableBytes: totalReclaimable)
        }.value
    }

    private static func computePartialHash(for url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        let sampleData = (try? handle.read(upToCount: 4096)) ?? Data()
        guard !sampleData.isEmpty else { return nil }

        let digest = SHA256.hash(data: sampleData)
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}
