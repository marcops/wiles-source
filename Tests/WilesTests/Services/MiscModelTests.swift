@testable import Wiles
import Foundation

@MainActor
public struct MiscModelTests {
    public static func run() {
        testWilesErrorDescriptions()
        testClipboardStateIsCut()
        testNetworkServerServiceEmptyAddressIsANoOp()
        testFolderNodeBuildRootTree()
        testFolderNodeRootChildrenSortedAndHiddenExcluded()
        testFolderNodeAutoExpandsOnlyHomeAncestors()
    }

    private static func testWilesErrorDescriptions() {
        let secretPath = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("secret").path
        let permissionDenied = WilesError.permissionDenied(path: secretPath)
        report("WilesError", "POS: permissionDenied includes the offending path", result: (permissionDenied.errorDescription ?? "").contains(secretPath))

        let fullPath = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("full").path
        let diskFull = WilesError.diskFull(path: fullPath)
        report("WilesError", "POS: diskFull includes the offending path", result: (diskFull.errorDescription ?? "").contains(fullPath))

        let operationFailed = WilesError.operationFailed(reason: "network unreachable")
        report("WilesError", "POS: operationFailed includes the given reason", result: (operationFailed.errorDescription ?? "").contains("network unreachable"))

        report("WilesError", "POS: invalidZipPassword has a non-empty description", result: !(WilesError.invalidZipPassword.errorDescription ?? "").isEmpty)
        report("WilesError", "NEG: two different error cases are not equal", result: permissionDenied != diskFull)
        report("WilesError", "POS: same case with same associated value is equal", result: WilesError.diskFull(path: "/x") == WilesError.diskFull(path: "/x"))
    }

    private static func testClipboardStateIsCut() {
        let tempBase = URL(fileURLWithPath: testTemporaryDirectory())
        let url = tempBase.appendingPathComponent("clip-test-\(UUID().uuidString).txt")
        let cutState = ClipboardState(urls: [url], action: .cut)
        report("ClipboardState", "POS: isCut(url:) is true for a URL that was cut", result: cutState.isCut(url: url))

        let otherURL = tempBase.appendingPathComponent("other-\(UUID().uuidString).txt")
        report("ClipboardState", "NEG: isCut(url:) is false for a URL not in the clipboard", result: !cutState.isCut(url: otherURL))

        let copyState = ClipboardState(urls: [url], action: .copy)
        report("ClipboardState", "NEG: isCut(url:) is false when the action is .copy, even for the same URL", result: !copyState.isCut(url: url))
    }

    private static func testNetworkServerServiceEmptyAddressIsANoOp() {
        var threw = false
        do {
            try NetworkServerService.connectToServer(urlAddress: "   ")
        } catch {
            threw = true
        }
        report("NetworkServerService", "NEG: blank/whitespace-only address does not throw (early return, no-op)", result: !threw)
    }

    private static func testFolderNodeBuildRootTree() {
        let root = FolderNode.buildRootTree()
        report("FolderNode", "POS: buildRootTree() root id/url points at the filesystem root", result: root.url == URL(fileURLWithPath: "/"))
        report("FolderNode", "POS: buildRootTree() finds at least one visible top-level folder", result: (root.children?.isEmpty ?? true) == false)
    }

    private static func testFolderNodeRootChildrenSortedAndHiddenExcluded() {
        let root = FolderNode.buildRootTree()
        let children = root.children ?? []
        report("FolderNode", "POS: root has at least one visible top-level folder to inspect", result: !children.isEmpty)

        let names = children.map { $0.name }
        let sortedNames = names.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        report("FolderNode", "POS: root children are sorted by localizedStandardCompare ascending", result: names == sortedNames)

        report("FolderNode", "NEG: no root child name starts with a dot (hidden folders are skipped)", result: !names.contains { $0.hasPrefix(".") })

        // Note: an earlier version of this test assumed "/tmp" (a symlink into /private/tmp) would
        // appear as a resolved directory entry. Verified directly against this macOS version: /tmp
        // reports BOTH isHidden == true AND isDirectory == false for the symlink itself (Foundation
        // does not resolve isDirectoryKey through it here) — so FolderNode correctly excludes it,
        // for two independent reasons the original assumption got backwards. No real test value in
        // asserting a specific well-known path's presence; the hidden-name check above already
        // covers the general exclusion behavior.
    }

    private static func testFolderNodeAutoExpandsOnlyHomeAncestors() {
        let root = FolderNode.buildRootTree()
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
        let homeComponents = home.pathComponents.filter { $0 != "/" }
        report("FolderNode", "POS: home directory has at least one path component to walk", result: !homeComponents.isEmpty)
        guard !homeComponents.isEmpty else { return }

        var current = root
        var walkedFullPath = true
        for component in homeComponents {
            guard let match = current.children?.first(where: { $0.name == component }) else {
                walkedFullPath = false
                break
            }
            current = match
        }
        report("FolderNode", "POS: every ancestor directory of the home folder is auto-expanded down to the home folder itself", result: walkedFullPath)

        // A root-level sibling that is NOT an ancestor of home should never have been recursed into.
        let firstHomeComponent = homeComponents[0]
        if let nonAncestorSibling = root.children?.first(where: { $0.name != firstHomeComponent }) {
            report("FolderNode", "NEG: a root child unrelated to the home directory path is not auto-expanded (children stays nil)", result: nonAncestorSibling.children == nil)
        }
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
