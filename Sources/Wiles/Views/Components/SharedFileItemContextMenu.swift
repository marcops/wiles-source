import SwiftUI
import AppKit

struct SharedFileItemContextMenu: View {
    let item: FileItem
    var appState: AppState
    @Environment(WindowUIState.self)
    private var windowUIState

    var body: some View {
        Button(appState.tr(.open)) { appState.navigateTo(item.url) }
        Button("\(appState.tr(.quickLook)) (Space)") { windowUIState.quickLookURL = item.url }
        Menu(appState.tr(.openWith)) {
            let availableApps = OpenWithService.availableApplications(for: item.url)
            ForEach(availableApps) { app in
                Button {
                    let targetURLs = appState.selectedURLs.isEmpty ? [item.url] : Array(appState.selectedURLs)
                    OpenWithService.open(urls: targetURLs, with: app.url)
                } label: {
                    Text(app.name)
                }
            }
            if !availableApps.isEmpty {
                Divider()
            }
            Button(appState.tr(.selectOtherApp)) {
                let targetURLs = appState.selectedURLs.isEmpty ? [item.url] : Array(appState.selectedURLs)
                OpenWithService.chooseOtherApplication(toOpen: targetURLs)
            }
            if !availableApps.isEmpty && !item.fileExtension.isEmpty {
                Divider()
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
        }
        if item.isUbiquitousNotDownloaded {
            Button(appState.tr(.downloadFromiCloud)) {
                let targetURLs = appState.selectedURLs.isEmpty ? [item.url] : Array(appState.selectedURLs)
                for url in targetURLs {
                    appState.downloadFromiCloud(url: url)
                }
            }
        }
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
        Button("\(appState.tr(.cut)) (Cmd+X)") {
            if !appState.selectedURLs.contains(item.url) { appState.selectedURLs = [item.url] }
            appState.cutSelected()
        }
        Button("\(appState.tr(.copy)) (Cmd+C)") {
            if !appState.selectedURLs.contains(item.url) { appState.selectedURLs = [item.url] }
            appState.copySelected()
        }
        Menu(appState.tr(.copyPath)) {
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
        Button("\(appState.tr(.paste)) (Cmd+V)") { appState.pasteToCurrentDirectory() }
        if !item.isDirectory {
            Button("\(appState.tr(.copyContent)) (#10)") {
                if !appState.selectedURLs.contains(item.url) { appState.selectedURLs = [item.url] }
                appState.copyContentOfSelected()
            }
            let isImage = ["png", "jpg", "jpeg", "heic", "webp", "tiff", "bmp", "gif"].contains(item.fileExtension.lowercased())
            if isImage {
                Button(appState.tr(.quickConvertImage)) {
                    if !appState.selectedURLs.contains(item.url) { appState.selectedURLs = [item.url] }
                    windowUIState.imageConverterItem = item
                }
            }
        }
        let pdfMergeTargets = appState.selectedURLs.contains(item.url) ? Array(appState.selectedURLs) : [item.url]
        let canMergePDF = pdfMergeTargets.allSatisfy { url in
            let ext = url.pathExtension.lowercased()
            return ext == "pdf" || ["png", "jpg", "jpeg", "heic", "webp", "tiff", "bmp", "gif"].contains(ext)
        }
        if canMergePDF && pdfMergeTargets.count >= 1 {
            Button(appState.tr(.mergeIntoPDF)) {
                Task {
                    do {
                        _ = try await PDFMergeService.mergeFiles(urls: pdfMergeTargets, in: appState.navigation.currentURL)
                    } catch {
                        appState.showError(error.localizedDescription)
                    }
                    appState.refreshCurrentDirectory()
                }
            }
        }
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
            if !appState.selectedURLs.contains(item.url) { appState.selectedURLs = [item.url] }
            appState.compressSelectedToZIP()
        }
        Button(appState.tr(.compressWithPassword)) {
            let targetURLs = appState.selectedURLs.contains(item.url) ? Array(appState.selectedURLs) : [item.url]
            windowUIState.passwordCompressURLs = targetURLs
            windowUIState.showPasswordCompressSheet = true
        }
        Divider()
        let renameHint = appState.navigationMode == .gnome ? "(F2)" : "(Return)"
        Button("\(appState.tr(.rename)) \(renameHint)") {
            if !appState.selectedURLs.contains(item.url) { appState.selectedURLs = [item.url] }
            if appState.selectedURLs.count > 1 {
                windowUIState.showBatchRenameSheet = true
            } else {
                windowUIState.renameItem = item
            }
        }
        Button(appState.tr(.moveToTrash), role: .destructive) {
            if !appState.selectedURLs.contains(item.url) { appState.selectedURLs = [item.url] }
            appState.deleteSelected(windowUIState: windowUIState)
        }
        Button("\(appState.tr(.deleteImmediately)) (Opt+Cmd+Del)", role: .destructive) {
            if !appState.selectedURLs.contains(item.url) { appState.selectedURLs = [item.url] }
            appState.deletePermanentlySelected()
        }
        Button(appState.tr(.secureShred), role: .destructive) {
            if !appState.selectedURLs.contains(item.url) { appState.selectedURLs = [item.url] }
            appState.shredSelected()
        }
        Button(appState.tr(.createSymlink)) {
            if !appState.selectedURLs.contains(item.url) { appState.selectedURLs = [item.url] }
            windowUIState.symlinkItem = item
        }
        Button("\(appState.tr(.airDrop))...") {
            if let airDrop = NSSharingService(named: .sendViaAirDrop) {
                airDrop.perform(withItems: [item.url])
            }
        }
        Divider()
        ShareLink(item: item.url) {
            Text(appState.tr(.services))
        }
        .labelStyle(.titleOnly)
        if appState.preferences.showTags {
            Menu(appState.tr(.tags)) {
                let predefinedTags = ["Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Gray"]
                let tagKeys: [String: L10n.Key] = [
                    "Red": .red, "Orange": .orange, "Yellow": .yellow, "Green": .green, "Blue": .blue, "Purple": .purple, "Gray": .gray
                ]
                let targetURLs = appState.selectedURLs.contains(item.url) ? Array(appState.selectedURLs) : [item.url]
                ForEach(predefinedTags, id: \.self) { tag in
                    Button {
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
                if !item.tags.isEmpty || targetURLs.count > 1 {
                    Divider()
                    Button(appState.tr(.clearAllTags)) {
                        Task.detached(priority: .userInitiated) {
                            var lastError: String?
                            for url in targetURLs {
                                do {
                                    try FileSystemService.setTags(for: url, tags: [])
                                } catch {
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
            }
        }
        Button("\(appState.tr(.properties)) (Cmd+I)") {
            if !appState.selectedURLs.contains(item.url) { appState.selectedURLs = [item.url] }
            windowUIState.propertiesItem = item
        }
    }
}

extension AppState {
    public func handleSelection(for item: FileItem) {
        let flags = NSEvent.modifierFlags
        if flags.contains(.command) {
            if selectedURLs.contains(item.url) {
                selectedURLs.remove(item.url)
            } else {
                selectedURLs.insert(item.url)
            }
        } else if flags.contains(.shift),
            let last = selectedURLs.first,
            let lastIdx = fileSystem.items.firstIndex(where: { $0.url == last }),
            let curIdx = fileSystem.items.firstIndex(where: { $0.url == item.url }) {
            let range = min(lastIdx, curIdx)...max(lastIdx, curIdx)
            let rangeURLs = fileSystem.items[range].map { $0.url }
            selectedURLs.formUnion(rangeURLs)
        } else {
            selectedURLs = [item.url]
        }
    }

    public func handleDrop(providers: [NSItemProvider], targetFolder: URL) {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { droppedURL, _ in
                guard let droppedURL = droppedURL, droppedURL.standardizedFileURL != targetFolder.standardizedFileURL else { return }
                Task { @MainActor in
                    do {
                        _ = try FileSystemService.moveItem(at: droppedURL, toFolder: targetFolder)
                        self.refreshCurrentDirectory()
                    } catch {
                        self.showError(error)
                    }
                }
            }
        }
    }
}

public func colorForTag(_ tag: String) -> Color {
    switch tag.lowercased() {
    case "red": return .red
    case "orange": return .orange
    case "yellow": return .yellow
    case "green": return .green
    case "blue": return .blue
    case "purple": return .purple
    case "gray", "grey": return .gray
    default: return .secondary
    }
}
