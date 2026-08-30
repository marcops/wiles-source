import Foundation
import GitBeacon

public struct FileTaggingService: Sendable {
    /// Synchronous, per-file xattr writes — callers (`SharedFileItemContextMenu`) already run this
    /// inside `Task.detached`, so it must never be called directly on the main actor.
    /// Returns the number of URLs that failed, so the caller can report "N of M items" instead of
    /// just the last error's text.
    public static func toggleTag(_ tag: String, for targetURLs: [URL], itemsSnapshot: [FileItem]) -> Int {
        // One target state for the whole selection: add to all unless every item already has it,
        // then the whole selection ends up consistent (a mixed selection no longer flips per-file).
        let tagsByURL = Dictionary(uniqueKeysWithValues: targetURLs.map { ($0, currentTags(for: $0, in: itemsSnapshot)) })
        let shouldAdd = !targetURLs.allSatisfy { tagsByURL[$0]?.contains(tag) ?? false }
        var failureCount = 0
        for url in targetURLs {
            var newTags = tagsByURL[url] ?? []
            if shouldAdd {
                guard !newTags.contains(tag) else { continue }
                newTags.append(tag)
            } else {
                newTags.removeAll { $0 == tag }
            }
            do {
                try FileSystemService.setTags(for: url, tags: newTags)
            } catch {
                ErrorReporter.report(error, context: "Toggling tag")
                failureCount += 1
            }
        }
        return failureCount
    }

    /// The file's current tags: from the in-memory snapshot when it holds this URL, otherwise a
    /// direct `.tagNamesKey` read — not a full `FileItem.load`, which also does an icon IPC and
    /// resource-value batch that tagging never uses.
    static func currentTags(for url: URL, in itemsSnapshot: [FileItem]) -> [String] {
        if let snapshotTags = itemsSnapshot.first(where: { $0.url == url })?.tags {
            return snapshotTags
        }
        return (try? url.resourceValues(forKeys: [.tagNamesKey]))?.tagNames ?? []
    }

    /// Same off-main-thread requirement as `toggleTag` above.
    public static func clearAllTags(for targetURLs: [URL]) -> Int {
        var failureCount = 0
        for url in targetURLs {
            do {
                try FileSystemService.setTags(for: url, tags: [])
            } catch {
                ErrorReporter.report(error, context: "Clearing all tags")
                failureCount += 1
            }
        }
        return failureCount
    }
}
