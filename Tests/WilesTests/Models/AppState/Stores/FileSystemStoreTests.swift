import AppKit
import Foundation
@testable import Wiles

@MainActor
public struct FileSystemStoreTests {
    public static func run() {
        let store = FileSystemStore()
        report("Store/FileSystemStore", "POS: FileSystemStore items initially empty", result: store.items.isEmpty)
        report("Store/FileSystemStore", "POS: FileSystemStore isLoading initially false", result: !store.isLoading)

        testTotalFileSizeBytesTracksItemsAssignment()
    }

    private static func makeItem(name: String, size: Int64, isDirectory: Bool) -> FileItem {
        FileItem(
            url: URL(fileURLWithPath: "/tmp/\(name)"), name: name, isDirectory: isDirectory, size: size,
            dateModified: Date(timeIntervalSinceReferenceDate: 0), dateCreated: Date(timeIntervalSinceReferenceDate: 0),
            dateAccessed: nil, ownerName: "--", groupName: "--", isHidden: false, fileExtension: "",
            icon: NSImage(), tags: [], tagColor: nil, isUbiquitous: false,
            isUbiquitousNotDownloaded: false, isUbiquitousDownloading: false, isUbiquitousUploading: false)
    }

    private static func testTotalFileSizeBytesTracksItemsAssignment() {
        let store = FileSystemStore()
        report("Store/FileSystemStore", "POS: totalFileSizeBytes starts at 0", result: store.totalFileSizeBytes == 0)

        store.items = [makeItem(name: "a.txt", size: 100, isDirectory: false), makeItem(name: "b.txt", size: 250, isDirectory: false)]
        report(
            "Store/FileSystemStore",
            "POS: assigning items sets totalFileSizeBytes to the sum of non-directory sizes",
            result: store.totalFileSizeBytes == 350)

        store.items = [makeItem(name: "a.txt", size: 100, isDirectory: false), makeItem(name: "sub", size: 999, isDirectory: true)]
        report("Store/FileSystemStore", "NEG: directory items do not contribute to totalFileSizeBytes", result: store.totalFileSizeBytes == 100)

        store.items = [makeItem(name: "c.txt", size: 42, isDirectory: false)]
        report("Store/FileSystemStore", "POS: reassigning items recomputes totalFileSizeBytes", result: store.totalFileSizeBytes == 42)

        store.items = []
        report("Store/FileSystemStore", "POS: clearing items resets totalFileSizeBytes to 0", result: store.totalFileSizeBytes == 0)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
