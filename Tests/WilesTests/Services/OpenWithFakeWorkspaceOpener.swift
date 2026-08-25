import AppKit
import Foundation
@testable import Wiles

/// Records calls instead of touching the real OS — see `WorkspaceOpening`. This is what makes
/// `OpenWithService.open(urls:with:)`'s real call site finally safe to exercise: no real file needs
/// to exist, nothing can present a blocking system alert.
@MainActor
final class OpenWithFakeWorkspaceOpener: WorkspaceOpening {
    private(set) var openedURLPairs: [(urls: [URL], applicationURL: URL)] = []
    private(set) var openedSingleURLs: [URL] = []

    func open(
        _ urls: [URL],
        withApplicationAt applicationURL: URL,
        configuration _: NSWorkspace.OpenConfiguration,
        completionHandler: (@Sendable (NSRunningApplication?, (any Error)?) -> Void)?) {
        openedURLPairs.append((urls, applicationURL))
        completionHandler?(nil, nil)
    }

    func open(_ url: URL) -> Bool {
        openedSingleURLs.append(url)
        return true
    }
}
