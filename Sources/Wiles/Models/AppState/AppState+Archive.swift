import Foundation
import GitBeacon

public extension AppState {
    func compressSelectedToZIP() {
        let urls = Array(selection.selectedURLs)
        guard !urls.isEmpty else { return }
        let current = navigation.currentURL
        runDetachedFileOperation(context: "Compressing items to ZIP", taskTitle: tr(.compressingItemsEllipsis)) {
            try ArchiveService.compressToZIP(urls: urls, in: current)
        }
    }

    func compressSelectedToZIPWithPassword(_ password: String, urls: [URL]) {
        guard !urls.isEmpty else { return }
        let current = navigation.currentURL
        runDetachedFileOperation(context: "Compressing items to password-protected ZIP", taskTitle: tr(.compressingItemsEllipsis)) {
            try ArchiveService.compressToZIP(urls: urls, in: current, password: password)
        }
    }

    func extractArchive(url: URL) {
        let current = navigation.currentURL
        runDetachedFileOperation(context: "Extracting archive", taskTitle: tr(.extractingArchiveEllipsis)) {
            try ArchiveService.extractArchive(archiveURL: url, to: current)
        }
    }
}
