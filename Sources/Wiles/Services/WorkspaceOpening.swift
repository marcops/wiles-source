import AppKit

/// Abstracts the real `NSWorkspace` file/URL-opening calls behind a protocol so callers depend on
/// an injectable seam instead of `NSWorkspace.shared` directly — the same protocol-driven isolation
/// this project already uses for `FileSystemServiceProtocol`/`ThumbnailServiceProtocol` (see
/// `.agents/AGENTS.md` rule 3). Without this, `OpenWithService`/`NetworkServerService` had no way to
/// avoid exercising the real OS in a test: opening a file that's gone by the time NSWorkspace
/// processes the request, or a bogus network address, can present a real, blocking system alert
/// with no way to dismiss it programmatically.
@MainActor
public protocol WorkspaceOpening: Sendable {
    func open(
        _ urls: [URL],
        withApplicationAt applicationURL: URL,
        configuration: NSWorkspace.OpenConfiguration,
        completionHandler: (@Sendable (NSRunningApplication?, Error?) -> Void)?)
    @discardableResult
    func open(_ url: URL) -> Bool
}
