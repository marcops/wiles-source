import Foundation
import GitBeacon

public extension AppState {
    func compressSelectedToZIP() {
        let urls = Array(selection.selectedURLs)
        guard !urls.isEmpty else { return }
        let current = navigation.currentURL
        Task.detached(priority: .userInitiated) {
            do {
                try FileSystemService.compressToZIP(urls: urls, in: current)
            } catch {
                ErrorReporter.report(error, context: "Compressing items to ZIP")
                await MainActor.run { [weak self] in
                    self?.showError(error.localizedDescription)
                }
            }
            await MainActor.run { [weak self] in
                self?.refreshCurrentDirectory()
            }
        }
    }

    func compressSelectedToZIPWithPassword(_ password: String, urls: [URL]?) {
        guard let urls, !urls.isEmpty else { return }
        let current = navigation.currentURL
        Task.detached(priority: .userInitiated) {
            do {
                try ArchiveService.compressToZIP(urls: urls, in: current, password: password)
            } catch {
                ErrorReporter.report(error, context: "Compressing items to password-protected ZIP")
                await MainActor.run { [weak self] in
                    self?.showError(error.localizedDescription)
                }
            }
            await MainActor.run { [weak self] in
                self?.refreshCurrentDirectory()
            }
        }
    }

    func extractArchive(url: URL) {
        let current = navigation.currentURL
        Task.detached(priority: .userInitiated) {
            do {
                try FileSystemService.extractZIP(archiveURL: url, to: current)
            } catch {
                ErrorReporter.report(error, context: "Extracting archive")
                await MainActor.run { [weak self] in
                    self?.showError(error.localizedDescription)
                }
            }
            await MainActor.run { [weak self] in
                self?.refreshCurrentDirectory()
            }
        }
    }
}
