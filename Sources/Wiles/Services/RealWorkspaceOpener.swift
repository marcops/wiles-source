import AppKit

public struct RealWorkspaceOpener: WorkspaceOpening {
    public init() { }

    public func open(
        _ urls: [URL],
        withApplicationAt applicationURL: URL,
        configuration: NSWorkspace.OpenConfiguration,
        completionHandler: (@Sendable (NSRunningApplication?, (any Error)?) -> Void)?) {
        NSWorkspace.shared.open(urls, withApplicationAt: applicationURL, configuration: configuration, completionHandler: completionHandler)
    }

    @discardableResult
    public func open(_ url: URL) -> Bool {
        NSWorkspace.shared.open(url)
    }
}
