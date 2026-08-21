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

    private static let imageFileExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "webp", "tiff", "bmp", "gif"]

    /// Makes `item` the sole selection unless it's already part of the current selection.
    private func ensureItemIsSelected() {
        if !appState.selectedURLs.contains(item.url) {
            appState.selectedURLs = [item.url]
        }
    }

    /// The current selection, or just `item` when nothing is selected. Doesn't check membership.
    private var selectionURLsOrItem: [URL] {
        appState.selectedURLs.isEmpty ? [item.url] : Array(appState.selectedURLs)
    }

    /// The current selection when it includes `item`, otherwise just `item` alone.
    private var itemOrSelectionURLs: [URL] {
        appState.selectedURLs.contains(item.url) ? Array(appState.selectedURLs) : [item.url]
    }

    @ViewBuilder private var openSection: some View {
        Button(appState.tr(.open)) { appState.navigateTo(item.url) }
        Button(appState.trWithShortcutHint(.quickLook, shortcut: "Space")) { windowUIState.quickLookURL = item.url }
        Menu(appState.tr(.openWith)) {
            openWithMenuContent
        }
        if item.isUbiquitousNotDownloaded {
            Button(appState.tr(.downloadFromiCloud)) {
                for url in selectionURLsOrItem {
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
            ensureItemIsSelected()
            appState.cutSelected()
        }
        Button(appState.trWithShortcutHint(.copy, shortcut: "Cmd+C")) {
            ensureItemIsSelected()
            appState.copySelected()
        }
        Menu(appState.tr(.copyPath)) {
            copyPathMenuContent
        }
        Button(appState.trWithShortcutHint(.paste, shortcut: "Cmd+V")) { appState.pasteToCurrentDirectory() }
    }

    @ViewBuilder private var copyPathMenuContent: some View {
        Button(appState.tr(.copyPathAbsolute)) {
            CopyPathService.copy(urls: selectionURLsOrItem, variant: .absolute)
        }
        Button(appState.tr(.copyPathRelative)) {
            CopyPathService.copy(urls: selectionURLsOrItem, variant: .relative, relativeTo: appState.navigation.currentURL)
        }
        Button(appState.tr(.copyPathURL)) {
            CopyPathService.copy(urls: selectionURLsOrItem, variant: .fileURL)
        }
        Button(appState.tr(.copyPathTerminal)) {
            CopyPathService.copy(urls: selectionURLsOrItem, variant: .terminalEscaped)
        }
    }

    @ViewBuilder private var contentActionsSection: some View {
        if !item.isDirectory {
            Button(appState.trWithShortcutHint(.copyContent, shortcut: "#10")) {
                ensureItemIsSelected()
                appState.copyContentOfSelected()
            }
            if isImageFile {
                Button(appState.tr(.quickConvertImage)) {
                    ensureItemIsSelected()
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
        Self.imageFileExtensions.contains(item.fileExtension.lowercased())
    }

    private var pdfMergeTargets: [URL] {
        itemOrSelectionURLs
    }

    private var canMergeSelectedIntoPDF: Bool {
        let isEligible = pdfMergeTargets.allSatisfy { url in
            let ext = url.pathExtension.lowercased()
            return ext == "pdf" || Self.imageFileExtensions.contains(ext)
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
            ensureItemIsSelected()
            appState.compressSelectedToZIP()
        }
        Button(appState.tr(.compressWithPassword)) {
            windowUIState.passwordCompressURLs = itemOrSelectionURLs
            windowUIState.showPasswordCompressSheet = true
        }
    }

    @ViewBuilder private var destructiveActionsSection: some View {
        Divider()
        Button(appState.trWithShortcutHint(.rename, shortcut: renameKeyboardHint)) {
            ensureItemIsSelected()
            if appState.selectedURLs.count > 1 {
                windowUIState.showBatchRenameSheet = true
            } else {
                windowUIState.renameItem = item
            }
        }
        Button(appState.tr(.moveToTrash), role: .destructive) {
            ensureItemIsSelected()
            appState.deleteSelected(windowUIState: windowUIState)
        }
        Button(appState.trWithShortcutHint(.deleteImmediately, shortcut: "Opt+Cmd+Del"), role: .destructive) {
            ensureItemIsSelected()
            appState.deletePermanentlySelected()
        }
        Button(appState.tr(.secureShred), role: .destructive) {
            ensureItemIsSelected()
            appState.shredSelected()
        }
        Button(appState.tr(.createSymlink)) {
            ensureItemIsSelected()
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
            ensureItemIsSelected()
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
            OpenWithService.chooseOtherApplication(toOpen: selectionURLsOrItem)
        }
        if !availableApps.isEmpty, !item.fileExtension.isEmpty {
            Divider()
            changeDefaultAppMenu(availableApps: availableApps)
        }
    }

    private func openWithAppButton(app: ApplicationApp) -> some View {
        Button {
            OpenWithService.open(urls: selectionURLsOrItem, with: app.url)
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
        let targetURLs = itemOrSelectionURLs
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
            let lastError = FileTaggingService.toggleTag(tag, for: targetURLs, itemsSnapshot: itemsSnapshot)
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
            let lastError = FileTaggingService.clearAllTags(for: targetURLs)
            await MainActor.run {
                if let lastError {
                    appState.showError(lastError)
                }
                appState.refreshCurrentDirectory()
            }
        }
    }
}
