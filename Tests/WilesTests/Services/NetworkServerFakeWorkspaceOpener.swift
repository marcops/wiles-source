import AppKit
import XCTest
@testable import Wiles

/// Records calls instead of touching the real OS — see `WorkspaceOpening`. This is what makes
/// `NetworkServerService.connectToServer`'s real success path finally safe to exercise: no real
/// network mount is attempted, nothing can present a blocking system alert.
@MainActor
final class NetworkServerFakeWorkspaceOpener: WorkspaceOpening {
    private(set) var openedSingleURLs: [URL] = []
    /// When true, `open(_:)` reports failure — simulates a real connection failure (e.g. server
    /// unreachable) without attempting a real network mount.
    var shouldFailToOpen = false

    func open(
        _: [URL],
        withApplicationAt _: URL,
        configuration _: NSWorkspace.OpenConfiguration,
        completionHandler _: (@Sendable (NSRunningApplication?, Error?) -> Void)?) { }

    func open(_ url: URL) -> Bool {
        openedSingleURLs.append(url)
        return !shouldFailToOpen
    }
}
