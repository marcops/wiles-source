import XCTest
@testable import Wiles
import AppKit

/// Records calls instead of touching the real OS — see `WorkspaceOpening`. This is what makes
/// `NetworkServerService.connectToServer`'s real success path finally safe to exercise: no real
/// network mount is attempted, nothing can present a blocking system alert.
@MainActor
final class NetworkServerFakeWorkspaceOpener: WorkspaceOpening {
    private(set) var openedSingleURLs: [URL] = []

    func open(
        _ urls: [URL],
        withApplicationAt applicationURL: URL,
        configuration: NSWorkspace.OpenConfiguration,
        completionHandler: (@Sendable (NSRunningApplication?, Error?) -> Void)?
    ) {}

    func open(_ url: URL) -> Bool {
        openedSingleURLs.append(url)
        return true
    }
}
