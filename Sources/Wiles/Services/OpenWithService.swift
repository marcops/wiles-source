import AppKit
import Foundation
import UniformTypeIdentifiers

public final class OpenWithService: Sendable {
    /// Injectable seam for tests — see `WorkspaceOpening`. Defaults to the real `NSWorkspace`.
    @MainActor public static var opener: any WorkspaceOpening = RealWorkspaceOpener()

    /// `availableApplications` is rebuilt every time an "Open With" menu is shown, and the scan
    /// (LaunchServices query + per-app `Bundle`/`resourceValues`/icon resize) is the same for every
    /// file of a given type. Memoize it by extension so only the first menu per type pays that cost.
    @MainActor private static var applicationsByExtension: [String: [ApplicationApp]] = [:]
    /// Crude bound so a very long browsing session can't grow the cache without limit.
    private static let maxCachedExtensions = 200

    /// Drops the memoized results so a newly installed/removed app is picked up on the next menu.
    @MainActor
    public static func invalidateApplicationsCache() {
        applicationsByExtension.removeAll()
    }

    /// Cache hit returns synchronously; a miss runs the LaunchServices query + per-app
    /// `Bundle`/`resourceValues`/icon-resize scan on a detached task so the first "Open With" menu
    /// for a common type (e.g. `.txt`) doesn't freeze the main thread.
    @MainActor
    public static func availableApplications(for url: URL) async -> [ApplicationApp] {
        let ext = url.pathExtension.lowercased()
        if !ext.isEmpty, let cached = applicationsByExtension[ext] {
            return cached
        }
        let results = await Task.detached(priority: .userInitiated) {
            computeAvailableApplications(for: url)
        }.value
        if !ext.isEmpty {
            if applicationsByExtension.count >= maxCachedExtensions {
                applicationsByExtension.removeAll()
            }
            applicationsByExtension[ext] = results
        }
        return results
    }

    private nonisolated static func computeAvailableApplications(for url: URL) -> [ApplicationApp] {
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
    public static func chooseOtherApplication(toOpen urls: [URL], lang: AppLanguage = .system) {
        guard !urls.isEmpty else { return }
        let panel = NSOpenPanel()
        // Panel title must be set synchronously here; the caller supplies the in-app language.
        panel.title = L10n.string(.selectApplicationPanelTitle, lang: lang)
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
