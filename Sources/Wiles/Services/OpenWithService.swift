import AppKit
import Foundation
import UniformTypeIdentifiers

public final class OpenWithService: Sendable {
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
            // `.effectiveIconKey` reads the cached icon without a LaunchServices IPC round-trip per app.
            let iconValues = try? appURL.resourceValues(forKeys: [.effectiveIconKey])
            let rawIcon = (iconValues?.effectiveIcon as? NSImage) ?? NSWorkspace.shared.icon(forFile: appURL.path)
            let icon = rawIcon.resizedCopy(to: NSSize(width: 16, height: 16))

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
        // M5 follow-up: not a thrown error, so it can't route through WilesError.localized —
        // localizing this needs a `lang:` parameter threaded from the @MainActor caller.
        panel.title = L10n.string(.selectApplicationPanelTitle, lang: .system)
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
