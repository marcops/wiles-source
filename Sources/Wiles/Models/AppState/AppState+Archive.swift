import Foundation
import GitBeacon

public extension AppState {
    @discardableResult
    func compressSelectedToZIP() -> Task<Void, Never>? {
        let urls = Array(selection.selectedURLs)
        guard !urls.isEmpty else { return nil }
        let current = navigation.currentURL
        return runDetachedFileOperation(context: "Compressing items to ZIP", taskTitle: tr(.compressingItemsEllipsis), reportError: false) {
            try ArchiveService.compressToZIP(urls: urls, in: current)
        }
    }

    @discardableResult
    func compressSelectedToZIPWithPassword(_ password: String, urls: [URL]) -> Task<Void, Never>? {
        guard !urls.isEmpty else { return nil }
        let current = navigation.currentURL
        return runDetachedFileOperation(context: "Compressing items to password-protected ZIP", taskTitle: tr(.compressingItemsEllipsis), reportError: false) {
            try ArchiveService.compressToZIP(urls: urls, in: current, password: password)
        }
    }

    @discardableResult
    func extractArchive(url: URL) -> Task<Void, Never> {
        let current = navigation.currentURL
        return runDetachedFileOperation(context: "Extracting archive", taskTitle: tr(.extractingArchiveEllipsis), reportError: false) {
            try ArchiveService.extractArchive(archiveURL: url, to: current)
        }
    }
}
