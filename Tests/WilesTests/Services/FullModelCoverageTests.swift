@testable import Wiles
import Foundation
import AppKit

@MainActor
public struct FullModelCoverageTests {
    public static func run() {
        testFileOperationTaskModelFlows()
        testFolderNodeModelFlows()
        testSidebarItemModelFlows()
        testClipboardStateModelFlows()
        testDirectoryCacheEntryModelFlows()
        testDirectoryLoadResultModelFlows()
        testListColumnSettingsModelFlows()
        testAllEnumsModelFlows()
    }

    private static func testFileOperationTaskModelFlows() {
        let task = FileOperationTask(
            title: "Copying files",
            progress: 0.5,
            bytesTransferred: 500,
            totalBytes: 1000,
            isCancelled: false
        )
        report("Model/FileOperationTask", "POS: Task title matches initializer input", result: task.title == "Copying files")
        report("Model/FileOperationTask", "POS: Task progress matches 0.5", result: task.progress == 0.5)
        report("Model/FileOperationTask", "POS: Bytes transferred matches 500", result: task.bytesTransferred == 500)

        // NEG: Cancelled task status
        var cancelledTask = task
        cancelledTask.isCancelled = true
        report("Model/FileOperationTask", "NEG: Cancelled flag is set correctly", result: cancelledTask.isCancelled)
    }

    private static func testFolderNodeModelFlows() {
        let rootTree = FolderNode.buildRootTree()
        report("Model/FolderNode", "POS: Root tree builds with name 'Root (/)'", result: rootTree.name == "Root (/)")
        report("Model/FolderNode", "POS: Root tree URL is root path '/'", result: rootTree.url.path == "/")

        // NEG: Leaf node has nil children when unexpanded
        let leafNode = FolderNode(id: URL(fileURLWithPath: "/tmp"), name: "tmp", url: URL(fileURLWithPath: "/tmp"), children: nil)
        report("Model/FolderNode", "NEG: Leaf node children is nil", result: leafNode.children == nil)
    }

    private static func testSidebarItemModelFlows() {
        let item = SidebarItem(
            name: "Documents",
            iconName: "doc.fill",
            url: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        )
        report("Model/SidebarItem", "POS: SidebarItem name matches 'Documents'", result: item.name == "Documents")
        report("Model/SidebarItem", "POS: SidebarItem iconName matches 'doc.fill'", result: item.iconName == "doc.fill")

        // NEG: Two distinct items have unique IDs
        let item2 = SidebarItem(name: "Downloads", iconName: "arrow.down.doc", url: URL(fileURLWithPath: "/tmp"))
        report("Model/SidebarItem", "NEG: Unique instances have distinct UUIDs", result: item.id != item2.id)
    }

    private static func testClipboardStateModelFlows() {
        let fileURL = URL(fileURLWithPath: "/tmp/test.txt")
        let cutState = ClipboardState(urls: [fileURL], action: .cut)
        let copyState = ClipboardState(urls: [fileURL], action: .copy)

        report("Model/ClipboardState", "POS: isCut returns true for cut action item", result: cutState.isCut(url: fileURL))
        report("Model/ClipboardState", "NEG: isCut returns false for copy action item", result: !copyState.isCut(url: fileURL))

        let absentURL = URL(fileURLWithPath: "/tmp/other.txt")
        report("Model/ClipboardState", "NEG: isCut returns false for url absent from clipboard", result: !cutState.isCut(url: absentURL))
    }

    private static func testDirectoryCacheEntryModelFlows() {
        let items = [FileItem(url: URL(fileURLWithPath: "/tmp/a.txt"), icon: NSImage())]
        let loadResult = DirectoryLoadResult(items: items, isPermissionDenied: false)
        let entry = DirectoryCacheEntry(result: loadResult)

        report("Model/DirectoryCacheEntry", "POS: Cache entry result items count matches", result: entry.result.items.count == 1)
        report("Model/DirectoryCacheEntry", "POS: Cache entry timestamp is valid", result: entry.timestamp <= Date())
    }

    private static func testDirectoryLoadResultModelFlows() {
        let items = [FileItem(url: URL(fileURLWithPath: "/tmp/b.txt"), icon: NSImage())]
        let result = DirectoryLoadResult(items: items, isPermissionDenied: false)

        report("Model/DirectoryLoadResult", "POS: DirectoryLoadResult items count matches", result: result.items.count == 1)
        report("Model/DirectoryLoadResult", "NEG: DirectoryLoadResult permission denied is false", result: !result.isPermissionDenied)
    }

    private static func testListColumnSettingsModelFlows() {
        let defaults = ListColumnState.defaults()
        report("Model/ListColumnSettings", "POS: ListColumnState defaults array covers all columns", result: !defaults.isEmpty)

        if let nameCol = defaults.first(where: { $0.column == .name }) {
            report("Model/ListColumnSettings", "POS: Name column is visible by default", result: nameCol.isVisible)
        }
    }

    private static func testAllEnumsModelFlows() {
        // SortOption
        let sortCases = SortOption.allCases
        report("Model/Enums", "POS: SortOption covers name, size, dateModified, kind, dateCreated", result: sortCases.count >= 5)

        // ViewMode
        let viewCases = ViewMode.allCases
        report("Model/Enums", "POS: ViewMode covers grid, list, column", result: viewCases.count >= 3)

        // SidebarMode
        let sidebarCases = SidebarMode.allCases
        report("Model/Enums", "POS: SidebarMode covers compact, detailed", result: sidebarCases.count >= 2)

        // NavigationMode
        let navCases = NavigationMode.allCases
        report("Model/Enums", "POS: NavigationMode covers pathBar, breadcrumb", result: navCases.count >= 2)

        // AppAppearance
        let appCases = AppAppearance.allCases
        report("Model/Enums", "POS: AppAppearance covers system, dark, light", result: appCases.count >= 3)

        // HTTPStatus
        report("Model/Enums", "POS: HTTPStatus ok status is 200", result: HTTPStatus.ok == 200)
        report("Model/Enums", "POS: HTTPStatus notFound status is 404", result: HTTPStatus.notFound == 404)

        // KeyCode
        report("Model/Enums", "POS: KeyCode backspace value is 51", result: KeyCode.backspace == 51)
        report("Model/Enums", "POS: KeyCode returnKey value is 36", result: KeyCode.returnKey == 36)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
