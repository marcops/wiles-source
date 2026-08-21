import AppKit
import GitBeacon
import SwiftUI

struct SharedFileItemContextMenu: View {
    let item: FileItem
    var appState: AppState
    @Environment(WindowUIState.self)
    private var windowUIState

    var body: some View {
        openSection
        shareAndFavoriteSection
        clipboardSection
        contentActionsSection
        archiveAndCompressSection
        destructiveActionsSection
        shareTagsPropertiesSection
    }

    @ViewBuilder private var openSection: some View {
        Button(appState.tr(.open)) { appState.navigateTo(item.url) }
        Button(appState.trWithShortcutHint(.quickLook, shortcut: "Space")) { windowUIState.quickLookURL = item.url }
        Menu(appState.tr(.openWith)) {
            openWithMenuContent
        }
        if item.isUbiquitousNotDownloaded {
            Button(appState.tr(.downloadFromiCloud)) {
                let targetURLs = appState.selectedURLs.isEmpty ? [item.url] : Array(appState.selectedURLs)
                for url in targetURLs {
                    appState.downloadFromiCloud(url: url)
                }
            }
        }
    }

    @ViewBuilder private var shareAndFavoriteSection: some View {
        Divider()
        if item.isDirectory {
            Button(appState.tr(.shareFolderWifi)) {
                windowUIState.httpShareFolderURL = item.url
                windowUIState.showHttpShareSheet = true
            }
            if appState.isFavorite(item.url) {
                Button(appState.tr(.removeFromFavorites)) { appState.removeFavorite(item.url) }
            } else {
                Button(appState.tr(.addToFavorites)) { appState.addFavorite(item.url) }
            }
            Divider()
        }
    }

    @ViewBuilder private var clipboardSection: some View {
        Button(appState.trWithShortcutHint(.cut, shortcut: "Cmd+X")) {
            if !appState.selectedURLs.contains(item.url) {
                appState.selectedURLs = [item.url]
            }
            appState.cutSelected()
        }
        Button(appState.trWithShortcutHint(.copy, shortcut: "Cmd+C")) {
            if !appState.selectedURLs.contains(item.url) {
                appState.selectedURLs = [item.url]
            }
            appState.copySelected()
        }
        Menu(appState.tr(.copyPath)) {
            copyPathMenuContent
        }
        Button(appState.trWithShortcutHint(.paste, shortcut: "Cmd+V")) { appState.pasteToCurrentDirectory() }
    }

    @ViewBuilder private var copyPathMenuContent: some View {
        Button(appState.tr(.copyPathAbsolute)) {
            let target = appState.selectedURLs.isEmpty ? [item.url] : Array(appState.selectedURLs)
            CopyPathService.copy(urls: target, variant: .absolute)
        }
        Button(appState.tr(.copyPathRelative)) {
            let target = appState.selectedURLs.isEmpty ? [item.url] : Array(appState.selectedURLs)
            CopyPathService.copy(urls: target, variant: .relative, relativeTo: appState.navigation.currentURL)
        }
        Button(appState.tr(.copyPathURL)) {
            let target = appState.selectedURLs.isEmpty ? [item.url] : Array(appState.selectedURLs)
            CopyPathService.copy(urls: target, variant: .fileURL)
        }
        Button(appState.tr(.copyPathTerminal)) {
            let target = appState.selectedURLs.isEmpty ? [item.url] : Array(appState.selectedURLs)
            CopyPathService.copy(urls: target, variant: .terminalEscaped)
        }
    }

    @ViewBuilder private var contentActionsSection: some View {
        if !item.isDirectory {
            Button(appState.trWithShortcutHint(.copyContent, shortcut: "#10")) {
                if !appState.selectedURLs.contains(item.url) {
                    appState.selectedURLs = [item.url]
                }
                appState.copyContentOfSelected()
            }
            if isImageFile {
                Button(appState.tr(.quickConvertImage)) {
                    if !appState.selectedURLs.contains(item.url) {
                        appState.selectedURLs = [item.url]
                    }
                    windowUIState.imageConverterItem = item
                }
            }
        }
        if canMergeSelectedIntoPDF {
            Button(appState.tr(.mergeIntoPDF)) {
                Task {
                    do {
                        _ = try await PDFMergeService.mergeFiles(urls: pdfMergeTargets, in: appState.navigation.currentURL)
                    } catch {
                        ErrorReporter.report(error, context: "Merging files into PDF")
                        appState.showError(error.localizedDescription)
                    }
                    appState.refreshCurrentDirectory()
                }
            }
        }
    }

    private var isImageFile: Bool {
        ["png", "jpg", "jpeg", "heic", "webp", "tiff", "bmp", "gif"].contains(item.fileExtension.lowercased())
    }

    private var pdfMergeTargets: [URL] {
        appState.selectedURLs.contains(item.url) ? Array(appState.selectedURLs) : [item.url]
    }

    private var canMergeSelectedIntoPDF: Bool {
        let isEligible = pdfMergeTargets.allSatisfy { url in
            let ext = url.pathExtension.lowercased()
            return ext == "pdf" || ["png", "jpg", "jpeg", "heic", "webp", "tiff", "bmp", "gif"].contains(ext)
        }
        return isEligible && pdfMergeTargets.count >= 1
    }

    @ViewBuilder private var archiveAndCompressSection: some View {
        Divider()
        if ArchiveService.isArchive(url: item.url) {
            Button(appState.tr(.inspectArchive)) {
                windowUIState.inspectArchiveURL = item.url
                windowUIState.showArchiveInspectionSheet = true
            }
            Button(appState.tr(.extractArchive)) {
                appState.extractArchive(url: item.url)
            }
        }
        Button(appState.tr(.compressToZip)) {
            if !appState.selectedURLs.contains(item.url) {
                appState.selectedURLs = [item.url]
            }
            appState.compressSelectedToZIP()
        }
        Button(appState.tr(.compressWithPassword)) {
            let targetURLs = appState.selectedURLs.contains(item.url) ? Array(appState.selectedURLs) : [item.url]
            windowUIState.passwordCompressURLs = targetURLs
            windowUIState.showPasswordCompressSheet = true
        }
    }

    @ViewBuilder private var destructiveActionsSection: some View {
        Divider()
        Button(appState.trWithShortcutHint(.rename, shortcut: renameKeyboardHint)) {
            if !appState.selectedURLs.contains(item.url) {
                appState.selectedURLs = [item.url]
            }
            if appState.selectedURLs.count > 1 {
                windowUIState.showBatchRenameSheet = true
            } else {
                windowUIState.renameItem = item
            }
        }
        Button(appState.tr(.moveToTrash), role: .destructive) {
            if !appState.selectedURLs.contains(item.url) {
                appState.selectedURLs = [item.url]
            }
            appState.deleteSelected(windowUIState: windowUIState)
        }
        Button(appState.trWithShortcutHint(.deleteImmediately, shortcut: "Opt+Cmd+Del"), role: .destructive) {
            if !appState.selectedURLs.contains(item.url) {
                appState.selectedURLs = [item.url]
            }
            appState.deletePermanentlySelected()
        }
        Button(appState.tr(.secureShred), role: .destructive) {
            if !appState.selectedURLs.contains(item.url) {
                appState.selectedURLs = [item.url]
            }
            appState.shredSelected()
        }
        Button(appState.tr(.createSymlink)) {
            if !appState.selectedURLs.contains(item.url) {
                appState.selectedURLs = [item.url]
            }
            windowUIState.symlinkItem = item
        }
        Button("\(appState.tr(.airDrop))...") {
            if let airDrop = NSSharingService(named: .sendViaAirDrop) {
                airDrop.perform(withItems: [item.url])
            }
        }
    }

    private var renameKeyboardHint: String {
        appState.preferences.navigationMode == .gnome ? "F2" : "Return"
    }

    @ViewBuilder private var shareTagsPropertiesSection: some View {
        Divider()
        ShareLink(item: item.url) {
            Text(appState.tr(.services))
        }
        .labelStyle(.titleOnly)
        if appState.preferences.showTags {
            Menu(appState.tr(.tags)) {
                tagsMenuContent
            }
        }
        Button(appState.trWithShortcutHint(.properties, shortcut: "Cmd+I")) {
            if !appState.selectedURLs.contains(item.url) {
                appState.selectedURLs = [item.url]
            }
            windowUIState.propertiesItem = item
        }
    }

    @ViewBuilder private var openWithMenuContent: some View {
        let availableApps = OpenWithService.availableApplications(for: item.url)
        ForEach(availableApps) { app in
            openWithAppButton(app: app)
        }
        if !availableApps.isEmpty {
            Divider()
        }
        Button(appState.tr(.selectOtherApp)) {
            let targetURLs = appState.selectedURLs.isEmpty ? [item.url] : Array(appState.selectedURLs)
            OpenWithService.chooseOtherApplication(toOpen: targetURLs)
        }
        if !availableApps.isEmpty, !item.fileExtension.isEmpty {
            Divider()
            changeDefaultAppMenu(availableApps: availableApps)
        }
    }

    private func openWithAppButton(app: ApplicationApp) -> some View {
        Button {
            let targetURLs = appState.selectedURLs.isEmpty ? [item.url] : Array(appState.selectedURLs)
            OpenWithService.open(urls: targetURLs, with: app.url)
        } label: {
            Text(app.name)
        }
    }

    private func changeDefaultAppMenu(availableApps: [ApplicationApp]) -> some View {
        Menu(appState.tr(.changeAllDefaultApp) + "...") {
            ForEach(availableApps) { app in
                Button {
                    OpenWithService.setDefaultApplication(for: item.fileExtension, applicationURL: app.url)
                } label: {
                    Text(app.name)
                }
            }
        }
    }

    @ViewBuilder private var tagsMenuContent: some View {
        let predefinedTags = ["Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Gray"]
        let tagKeys: [String: L10n.Key] = [
            "Red": .red, "Orange": .orange, "Yellow": .yellow, "Green": .green, "Blue": .blue, "Purple": .purple, "Gray": .gray
        ]
        let targetURLs = appState.selectedURLs.contains(item.url) ? Array(appState.selectedURLs) : [item.url]
        ForEach(predefinedTags, id: \.self) { tag in
            tagToggleButton(tag: tag, tagKeys: tagKeys, targetURLs: targetURLs)
        }
        if !item.tags.isEmpty || targetURLs.count > 1 {
            Divider()
            Button(appState.tr(.clearAllTags)) {
                clearAllTags(targetURLs: targetURLs)
            }
        }
    }

    private func tagToggleButton(tag: String, tagKeys: [String: L10n.Key], targetURLs: [URL]) -> some View {
        Button {
            toggleTag(tag, targetURLs: targetURLs)
        } label: {
            HStack {
                if let key = tagKeys[tag] {
                    Text(appState.tr(key))
                } else {
                    Text(tag)
                }
                if item.tags.contains(tag) {
                    Image(systemName: "checkmark")
                }
            }
        }
    }

    private func toggleTag(_ tag: String, targetURLs: [URL]) {
        let itemsSnapshot = appState.fileSystem.items
        Task.detached(priority: .userInitiated) {
            var lastError: String?
            for url in targetURLs {
                let fallbackItem = FileItem(url: url, icon: NSWorkspace.shared.icon(forFile: url.path), fetchTags: true)
                let currentItem = itemsSnapshot.first(where: { $0.url == url }) ?? fallbackItem
                var newTags = currentItem.tags
                if newTags.contains(tag) {
                    newTags.removeAll { $0 == tag }
                } else {
                    newTags.append(tag)
                }
                do {
                    try FileSystemService.setTags(for: url, tags: newTags)
                } catch {
                    ErrorReporter.report(error, context: "Toggling tag")
                    lastError = error.localizedDescription
                }
            }
            await MainActor.run {
                if let lastError {
                    appState.showError(lastError)
                }
                appState.refreshCurrentDirectory()
            }
        }
    }

    private func clearAllTags(targetURLs: [URL]) {
        Task.detached(priority: .userInitiated) {
            var lastError: String?
            for url in targetURLs {
                do {
                    try FileSystemService.setTags(for: url, tags: [])
                } catch {
                    ErrorReporter.report(error, context: "Clearing all tags")
                    lastError = error.localizedDescription
                }
            }
            await MainActor.run {
                if let lastError {
                    appState.showError(lastError)
                }
                appState.refreshCurrentDirectory()
            }
        }
    }
}
