import AppKit
import SwiftUI

struct SharedFileItemContextMenu: View {
    let item: FileItem
    var appState: AppState
    @Environment(WindowUIState.self)
    private var windowUIState
    @State private var openWithApps: [ApplicationApp]?

    var body: some View {
        openSection
        shareAndFavoriteSection
        clipboardSection
        contentActionsSection
        archiveAndCompressSection
        destructiveActionsSection
        shareTagsPropertiesSection
    }

    /// Every menu action operates on this. Right-click already guarantees `item` is in the
    /// selection before the menu opens (`FileItemInteractionsModifier`'s `RightClickDetector`), so
    /// there's no per-action "ensure selected" step and no item-vs-selection fallback to reconcile.
    private var actionURLs: [URL] {
        Array(appState.selection.selectedURLs)
    }

    @ViewBuilder private var openSection: some View {
        Button(appState.tr(.open)) { appState.openItem(item.url) }
        Button(appState.trWithShortcutHint(.quickLook, shortcut: ShortcutRegistry.label(.quickLook))) { windowUIState.quickLookURL = item.url }
        Menu(appState.tr(.openWith)) {
            openWithMenuContent
        }
        .task(id: item.url) { openWithApps = await OpenWithService.availableApplications(for: item.url) }
        if item.isUbiquitousNotDownloaded {
            Button(appState.tr(.downloadFromiCloud)) {
                for url in actionURLs {
                    appState.downloadFromiCloud(url: url)
                }
            }
        }
    }

    @ViewBuilder private var shareAndFavoriteSection: some View {
        Divider()
        if item.isDirectory {
            Button(appState.tr(.shareFolderWifi)) {
                windowUIState.activeModal = .httpShare(item.url)
            }
            FavoriteToggleButton(url: item.url, appState: appState)
            Divider()
        }
    }

    @ViewBuilder private var clipboardSection: some View {
        Button(appState.trWithShortcutHint(.cut, shortcut: ShortcutRegistry.label(.cut))) {
            appState.cutSelected()
        }
        Button(appState.trWithShortcutHint(.copy, shortcut: ShortcutRegistry.label(.copy))) {
            appState.copySelected()
        }
        Menu(appState.tr(.copyPath)) {
            CopyPathMenuContent(urls: actionURLs, relativeTo: appState.navigation.currentURL, appState: appState)
        }
        Button(appState.trWithShortcutHint(.paste, shortcut: ShortcutRegistry.label(.paste))) { appState.pasteToCurrentDirectory(windowUIState: windowUIState) }
    }

    @ViewBuilder private var contentActionsSection: some View {
        if !item.isDirectory {
            Button(appState.tr(.copyContent)) {
                appState.copyContentOfSelected()
            }
            if isImageFile {
                Button(appState.tr(.quickConvertImage)) {
                    windowUIState.activeModal = .imageConverter(item)
                }
            }
        }
        if canMergeSelectedIntoPDF {
            Button(appState.tr(.mergeIntoPDF)) {
                mergeSelectedIntoPDF()
            }
        }
    }

    /// Routes the merge through `runDetachedFileOperation(taskTitle:)` so it shows a progress entry
    /// in the operations popover and its ✕ actually cancels the merge (`PDFMergeService` checks
    /// `Task.checkCancellation` per file) — instead of a bare `Task {}` with no UI signal.
    private func mergeSelectedIntoPDF() {
        let targets = pdfMergeTargets
        let folder = appState.navigation.currentURL
        appState.runDetachedFileOperation(
            context: "Merging files into PDF",
            taskTitle: appState.tr(.mergeIntoPDF),
            onSuccess: { [appState] (result: (url: URL, skippedCount: Int)) in
                if result.skippedCount > 0 {
                    appState.showError(WilesError.localized(key: .pdfMergePartialFailure, arguments: ["\(result.skippedCount)"]))
                }
                appState.selection.selectedURLs = [result.url]
            },
            operation: { try await PDFMergeService.mergeFiles(urls: targets, in: folder) })
    }

    private var isImageFile: Bool {
        ImageFileType.isImage(fileExtension: item.fileExtension)
    }

    private var pdfMergeTargets: [URL] {
        actionURLs
    }

    private var canMergeSelectedIntoPDF: Bool {
        let isEligible = pdfMergeTargets.allSatisfy { url in
            let ext = url.pathExtension.lowercased()
            return ext == "pdf" || ImageFileType.isImage(fileExtension: ext)
        }
        return isEligible && pdfMergeTargets.count >= 2
    }

    @ViewBuilder private var archiveAndCompressSection: some View {
        Divider()
        if ArchiveService.isArchive(url: item.url) {
            Button(appState.tr(.inspectArchive)) {
                windowUIState.activeModal = .inspectArchive(item.url)
            }
            Button(appState.tr(.extractArchive)) {
                appState.extractArchive(url: item.url)
            }
        }
        Button(appState.tr(.compressToZip)) {
            appState.compressSelectedToZIP()
        }
        Button(appState.tr(.compressWithPassword)) {
            windowUIState.activeModal = .passwordCompress(actionURLs)
        }
    }

    @ViewBuilder private var destructiveActionsSection: some View {
        Divider()
        Button(appState.trWithShortcutHint(.rename, shortcut: renameKeyboardHint)) {
            if appState.selection.selectedURLs.count > 1 {
                windowUIState.activeModal = .batchRename
            } else {
                windowUIState.renameItem = item
            }
        }
        Button(appState.trWithShortcutHint(.moveToTrash, shortcut: ShortcutRegistry.label(.moveToTrash)), role: .destructive) {
            appState.deleteSelected(windowUIState: windowUIState)
        }
        Button(appState.tr(.deleteImmediately), role: .destructive) {
            appState.deletePermanentlySelected(windowUIState: windowUIState)
        }
        Button(appState.tr(.createSymlink)) {
            windowUIState.activeModal = .symlink(item)
        }
        Button(appState.tr(.airDropEllipsis)) {
            if let airDrop = NSSharingService(named: .sendViaAirDrop) {
                airDrop.perform(withItems: actionURLs)
            }
        }
    }

    private var renameKeyboardHint: String {
        ShortcutRegistry.label(appState.preferences.view.navigationMode == .gnome ? .renameGnome : .renameMacOS)
    }

    @ViewBuilder private var shareTagsPropertiesSection: some View {
        Divider()
        ShareLink(items: actionURLs) {
            Text(appState.tr(.share))
        }
        .labelStyle(.titleOnly)
        if appState.preferences.sidebar.showTags {
            Menu(appState.tr(.tags)) {
                tagsMenuContent
            }
        }
        Button(appState.trWithShortcutHint(.properties, shortcut: ShortcutRegistry.label(.properties))) {
            windowUIState.activeModal = .properties(item)
        }
    }

    @ViewBuilder private var openWithMenuContent: some View {
        if let availableApps = openWithApps {
            ForEach(availableApps) { app in
                openWithAppButton(app: app)
            }
            if !availableApps.isEmpty {
                Divider()
            }
            Button(appState.tr(.selectOtherApp)) {
                OpenWithService.chooseOtherApplication(toOpen: actionURLs, lang: appState.preferences.appearance.appLanguage)
            }
            if !availableApps.isEmpty, !item.fileExtension.isEmpty {
                Divider()
                changeDefaultAppMenu(availableApps: availableApps)
            }
        } else {
            Button(appState.tr(.loadingApplications)) { }
                .disabled(true)
        }
    }

    private func openWithAppButton(app: ApplicationApp) -> some View {
        Button {
            OpenWithService.open(urls: actionURLs, with: app.url)
        } label: {
            Text(app.name)
        }
    }

    private func changeDefaultAppMenu(availableApps: [ApplicationApp]) -> some View {
        Menu(appState.tr(.changeAllDefaultAppEllipsis)) {
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
        let targetURLs = actionURLs
        ForEach(SystemTagsService.favoriteTags, id: \.self) { systemTag in
            tagToggleButton(
                tag: systemTag.name,
                displayName: systemTag.displayName(language: appState.preferences.appearance.appLanguage),
                targetURLs: targetURLs)
        }
        if !item.tags.isEmpty || targetURLs.count > 1 {
            Divider()
            Button(appState.tr(.clearAllTags)) {
                clearAllTags(targetURLs: targetURLs)
            }
        }
    }

    private func tagToggleButton(tag: String, displayName: String, targetURLs: [URL]) -> some View {
        Button {
            toggleTag(tag, targetURLs: targetURLs)
        } label: {
            HStack {
                Text(displayName)
                if item.tags.contains(tag) {
                    Image(systemName: "checkmark")
                }
            }
        }
    }

    private func toggleTag(_ tag: String, targetURLs: [URL]) {
        let itemsSnapshot = appState.fileSystem.items
        Task.detached(priority: .userInitiated) {
            let failureCount = FileTaggingService.toggleTag(tag, for: targetURLs, itemsSnapshot: itemsSnapshot)
            await MainActor.run {
                reportTagFailures(failureCount, total: targetURLs.count)
                appState.refreshCurrentDirectory()
            }
        }
    }

    private func clearAllTags(targetURLs: [URL]) {
        Task.detached(priority: .userInitiated) {
            let failureCount = FileTaggingService.clearAllTags(for: targetURLs)
            await MainActor.run {
                reportTagFailures(failureCount, total: targetURLs.count)
                appState.refreshCurrentDirectory()
            }
        }
    }

    private func reportTagFailures(_ failureCount: Int, total: Int) {
        guard failureCount > 0 else { return }
        appState.showPartialFailure(.tagOperationPartialFailure, failed: failureCount, total: total)
    }
}
