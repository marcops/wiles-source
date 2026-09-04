import Foundation
import GitBeacon
import Network

/// Directory-listing HTML for `LocalHttpServerService`: building the `<li>` list, resolving the
/// root-relative link prefix, and assembling the whole page off `queue` so a huge shared subfolder
/// doesn't stall other in-flight connections. Split from the main file to keep it under
/// the line-count cap.
extension LocalHttpServerService {
    /// The listing page is static HTML with inline styles and no scripts; lock everything else down
    /// so an entry name that still slipped markup through can't load or run anything.
    static let listingContentSecurityPolicy =
        "default-src 'none'; style-src 'unsafe-inline'; img-src 'self'; base-uri 'none'; form-action 'none'"

    /// Cap on entries rendered into one directory listing — the whole HTML page is buffered in RAM
    /// before it's sent, so a folder with hundreds of thousands of files can't turn into a
    /// hundreds-of-MB response. Aligned with `FileSystemService.recursiveSearchResultLimit`.
    static let maxListingEntries = 2000

    enum DirectoryListingResult: Sendable {
        case ok(html: String)
        case failure(status: Int, message: String)
    }

    /// The `contentsOfDirectory` + per-entry `isDirectory` reads + template render for a huge shared
    /// subfolder can take a while; `serveDirectoryListing` runs this on a detached task and hops back
    /// to `queue` only for `sendResponse`.
    nonisolated static func buildDirectoryListing(folder: URL, shareRoot: URL) -> DirectoryListingResult {
        do {
            // Hidden entries are never listed over the LAN — sharing a project folder must not
            // expose `.git/`, `.env`, `.ssh`, `.DS_Store`, etc. `serveFile` refuses them too.
            let allURLs = try FileManager.default.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            let sorted = allURLs.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
            let rawLanguage = UserDefaults.standard.string(forKey: DefaultsKey.appLanguage.rawValue) ?? AppLanguage.system.rawValue
            let language = AppLanguage(rawValue: rawLanguage) ?? .system
            let items = listingItemsHTML(
                sorted: sorted, linkPrefix: listingLinkPrefix(for: folder, shareRoot: shareRoot), language: language)

            guard let html = TemplateRenderingService.render(
                resource: "SharedFolder",
                replacements: [
                    "FOLDER_NAME": HTMLEscaping.escape(folder.lastPathComponent),
                    "ITEMS": items,
                    "PAGE_TITLE": L10n.string(.sharedFolderPageTitle, lang: language),
                    "HEADING": L10n.string(.sharedFolderHeading, lang: language)
                ]) else {
                return .failure(status: HTTPStatus.internalServerError, message: "Missing SharedFolder template")
            }
            return .ok(html: html)
        } catch {
            ErrorReporter.report(error, context: "Serving directory listing over local HTTP share")
            return .failure(status: HTTPStatus.internalServerError, message: "Error reading directory")
        }
    }

    /// URL-path prefix (percent-encoded, leading slash, no trailing slash) locating `folder` inside
    /// `shareRoot`, so a nested listing's links stay root-relative like the request paths
    /// `serveFile` resolves. Empty when `folder` is the share root itself.
    nonisolated static func listingLinkPrefix(for folder: URL, shareRoot: URL) -> String {
        let rootComponents = shareRoot.resolvingSymlinksInPath().pathComponents
        let relativeComponents = folder.resolvingSymlinksInPath().pathComponents.dropFirst(rootComponents.count)
        return relativeComponents.reduce(into: "") { result, component in
            // Escape the fallback: `addingPercentEncoding` returns nil for a lone surrogate, and the
            // raw value lands in an `href` attribute.
            result += "/" + (component.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
                ?? HTMLEscaping.escape(component))
        }
    }

    /// The `<li>` list for a directory listing, capped at `maxListingEntries` with a localized
    /// "listing truncated" note when the folder has more.
    nonisolated static func listingItemsHTML(sorted: [URL], linkPrefix: String, language: AppLanguage) -> String {
        var items = sorted.prefix(maxListingEntries).map { url -> String in
            let name = url.lastPathComponent
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            // Escape the fallback: `addingPercentEncoding` returns nil for a lone surrogate, which
            // would otherwise put the raw name (incl. a `"`) straight into the `href` attribute.
            let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
                ?? HTMLEscaping.escape(name)
            let href = "\(linkPrefix)/\(encoded)" + (isDirectory ? "/" : "")
            let label = HTMLEscaping.escape(name) + (isDirectory ? "/" : "")
            let marker = isDirectory ? "\u{1F4C1} " : ""
            return "<li style='margin-bottom: 8px;'><a href=\"\(href)\" style='text-decoration: none; color: #0066cc;'>\(marker)\(label)</a></li>"
        }.joined()
        if sorted.count > maxListingEntries {
            let note = L10n.string(.sharedFolderListingTruncated, lang: language)
                .replacingOccurrences(of: "{0}", with: "\(sorted.count - maxListingEntries)")
            items += "<li style='margin-top: 12px; color: #999;'>\(HTMLEscaping.escape(note))</li>"
        }
        return items
    }
}
