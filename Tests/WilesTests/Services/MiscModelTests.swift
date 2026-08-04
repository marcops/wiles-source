@testable import Wiles
import Foundation

@MainActor
public struct MiscModelTests {
    public static func run() {
        testWilesErrorDescriptions()
        testClipboardStateIsCut()
        testNetworkServerServiceEmptyAddressIsANoOp()
        testFolderNodeBuildRootTree()
    }

    private static func testWilesErrorDescriptions() {
        let secretPath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("secret").path
        let permissionDenied = WilesError.permissionDenied(path: secretPath)
        report("WilesError", "POS: permissionDenied includes the offending path", result: (permissionDenied.errorDescription ?? "").contains(secretPath))

        let fullPath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("full").path
        let diskFull = WilesError.diskFull(path: fullPath)
        report("WilesError", "POS: diskFull includes the offending path", result: (diskFull.errorDescription ?? "").contains(fullPath))

        let operationFailed = WilesError.operationFailed(reason: "network unreachable")
        report("WilesError", "POS: operationFailed includes the given reason", result: (operationFailed.errorDescription ?? "").contains("network unreachable"))

        report("WilesError", "POS: invalidZipPassword has a non-empty description", result: !(WilesError.invalidZipPassword.errorDescription ?? "").isEmpty)
        report("WilesError", "NEG: two different error cases are not equal", result: permissionDenied != diskFull)
        report("WilesError", "POS: same case with same associated value is equal", result: WilesError.diskFull(path: "/x") == WilesError.diskFull(path: "/x"))
    }

    private static func testClipboardStateIsCut() {
        let tempBase = URL(fileURLWithPath: NSTemporaryDirectory())
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

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
