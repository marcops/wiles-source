import AppKit
import Foundation
import GitBeacon

public struct FileTaggingService: Sendable {
    /// Synchronous, per-file xattr writes — callers (`SharedFileItemContextMenu`) already run this
    /// inside `Task.detached`, so it must never be called directly on the main actor.
    /// Returns the number of URLs that failed, so the caller can report "N of M items" instead of
    /// just the last error's text.
    public static func toggleTag(_ tag: String, for targetURLs: [URL], itemsSnapshot: [FileItem]) -> Int {
        var failureCount = 0
        for url in targetURLs {
            let fallbackItem = FileItem(url: url, icon: NSWorkspace.shared.icon(forFile: url.path), fetchTags: true)
            let currentItem = itemsSnapshot.first(where: { $0.url == url }) ?? fallbackItem
            var newTags = currentItem.tags
            if newTags.contains(tag) {
                newTags.removeAll { $0 == tag }
            } else {
                newTags.append(tag)
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
