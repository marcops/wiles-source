import AppKit
import Foundation
import GitBeacon

public struct FileTaggingService: Sendable {
    public static func toggleTag(_ tag: String, for targetURLs: [URL], itemsSnapshot: [FileItem]) -> String? {
        var lastError: String?
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
                lastError = error.localizedDescription
            }
        }
        return lastError
    }

    public static func clearAllTags(for targetURLs: [URL]) -> String? {
        var lastError: String?
        for url in targetURLs {
            do {
                try FileSystemService.setTags(for: url, tags: [])
            } catch {
                ErrorReporter.report(error, context: "Clearing all tags")
                lastError = error.localizedDescription
            }
        }
        return lastError
    }
}
