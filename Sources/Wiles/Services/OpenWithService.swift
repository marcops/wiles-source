import Foundation
import AppKit
import UniformTypeIdentifiers

public struct ApplicationApp: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let icon: NSImage
    public let url: URL

    public init(id: String, name: String, icon: NSImage, url: URL) {
        self.id = id
        self.name = name
        self.icon = icon
        self.url = url
    }
}

@MainActor
public protocol OpenWithServiceProtocol: Sendable {
    static func availableApplications(for url: URL) -> [ApplicationApp]
    static func open(urls: [URL], with applicationURL: URL)
    static func chooseOtherApplication(toOpen urls: [URL])
    static func setDefaultApplication(for fileExtension: String, applicationURL: URL)
}

public final class OpenWithService: OpenWithServiceProtocol, Sendable {
    /// Injectable seam for tests — see `WorkspaceOpening`. Defaults to the real `NSWorkspace`.
    @MainActor public static var opener: any WorkspaceOpening = RealWorkspaceOpener()

    @MainActor
    public static func availableApplications(for url: URL) -> [ApplicationApp] {
        let appURLs = NSWorkspace.shared.urlsForApplications(toOpen: url)
        var results: [ApplicationApp] = []
        var seenBundleIDs = Set<String>()

        for appURL in appURLs {
            let bundle = Bundle(url: appURL)
            let bundleID = bundle?.bundleIdentifier ?? appURL.lastPathComponent
            guard !seenBundleIDs.contains(bundleID) else { continue }
            seenBundleIDs.insert(bundleID)

            let displayName = FileManager.default.displayName(atPath: appURL.path).replacingOccurrences(of: ".app", with: "")
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            icon.size = NSSize(width: 16, height: 16)

            results.append(ApplicationApp(id: bundleID, name: displayName, icon: icon, url: appURL))
        }
        return results.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    @MainActor
    public static func open(urls: [URL], with applicationURL: URL) {
        guard !urls.isEmpty else { return }
        let config = NSWorkspace.OpenConfiguration()
        opener.open(urls, withApplicationAt: applicationURL, configuration: config, completionHandler: nil)
    }

    @MainActor
    public static func chooseOtherApplication(toOpen urls: [URL]) {
        guard !urls.isEmpty else { return }
        let panel = NSOpenPanel()
        panel.title = "Select Application"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        panel.begin { response in
            if response == .OK, let appURL = panel.url {
                open(urls: urls, with: appURL)
            }
        }
    }

    @MainActor
    public static func setDefaultApplication(for fileExtension: String, applicationURL: URL) {
        guard let uti = UTType(tag: fileExtension, tagClass: .filenameExtension, conformingTo: nil) else { return }
        NSWorkspace.shared.setDefaultApplication(at: applicationURL, toOpen: uti) { _ in }
    }
}
