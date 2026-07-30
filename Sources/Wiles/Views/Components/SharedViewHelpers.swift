import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct TranslucentVisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
    }
}

struct SharedBackgroundContextMenu: View {
    var appState: AppState

    var body: some View {
        Button("\(appState.tr(.newFolder)) (Shift+Cmd+N)") {
            appState.showNewFolderSheet = true
        }
        Button("\(appState.tr(.newFileTitle))...") {
            appState.showNewFileSheet = true
        }
        if appState.clipboard != nil {
            Button("\(appState.tr(.paste)) (Cmd+V)") {
                appState.pasteToCurrentDirectory()
            }
        } else {
            Button("\(appState.tr(.paste)) (Cmd+V)") {}.disabled(true)
        }
        Button("\(appState.tr(.selectAll)) (Cmd+A)") {
            appState.selectedURLs = Set(appState.items.map { $0.url })
        }
        Divider()
        Menu(appState.tr(.sortBy)) {
            ForEach(SortOption.allCases) { opt in
                Button(action: {
                    appState.sortOption = opt
                    appState.refreshCurrentDirectory()
                }) {
                    HStack {
                        Text(opt.rawValue)
                        if appState.sortOption == opt {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
        Menu(appState.tr(.viewMode)) {
            Button(appState.tr(.gridView)) { appState.viewMode = .grid }
            Button(appState.tr(.listView)) { appState.viewMode = .list }
        }
        Toggle(appState.navigationMode == .gnome ? appState.tr(.showHiddenFilesGnome) : appState.tr(.showHiddenFilesMac), isOn: Binding(
            get: { appState.showHiddenFiles },
            set: { appState.showHiddenFiles = $0; appState.refreshCurrentDirectory() }
        ))
        Divider()
        Button("\(appState.tr(.refresh)) (Cmd+R)") {
            appState.refreshCurrentDirectory()
        }
        Button(appState.tr(.copyPath)) {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(appState.currentURL.path, forType: .string)
        }
        Button("\(appState.tr(.diskUsageVisualizer))... (Shift+Cmd+D)") {
            appState.showDiskUsageSheet = true
        }
        Divider()
        Button(appState.tr(.folderProperties)) {
            let fileItem = FileItem(url: appState.currentURL, icon: NSWorkspace.shared.icon(forFile: appState.currentURL.path))
            appState.propertiesItem = fileItem
        }
    }
}

struct SharedFileItemContextMenu: View {
    let item: FileItem
    var appState: AppState

    var body: some View {
        Button(appState.tr(.open)) { appState.navigateTo(item.url) }
        Button("\(appState.tr(.quickLook)) (Space)") { appState.quickLookURL = item.url }
        Divider()
        if item.isDirectory {
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
                    appState.imageConverterItem = item
                }
            }
        }
        Divider()
        if ArchiveService.isArchive(url: item.url) {
            Button(appState.tr(.extractArchive)) {
                appState.extractArchive(url: item.url)
            }
        }
        Button(appState.tr(.compressToZip)) {
            if !appState.selectedURLs.contains(item.url) { appState.selectedURLs = [item.url] }
            appState.compressSelectedToZIP()
        }
        Divider()
        let renameHint = appState.navigationMode == .gnome ? "(F2)" : "(Return)"
        Button("\(appState.tr(.rename)) \(renameHint)") {
            if !appState.selectedURLs.contains(item.url) { appState.selectedURLs = [item.url] }
            if appState.selectedURLs.count > 1 {
                appState.showBatchRenameSheet = true
            } else {
                appState.renameItem = item
            }
        }
        Button(appState.tr(.moveToTrash), role: .destructive) {
            if !appState.selectedURLs.contains(item.url) { appState.selectedURLs = [item.url] }
            appState.deleteSelected()
        }
        Button("Delete Immediately (Opt+Cmd+Del)", role: .destructive) {
            if !appState.selectedURLs.contains(item.url) { appState.selectedURLs = [item.url] }
            appState.deletePermanentlySelected()
        }
        Button("Secure Shred File...", role: .destructive) {
            if !appState.selectedURLs.contains(item.url) { appState.selectedURLs = [item.url] }
            appState.shredSelected()
        }
        Button("Create Symlink...") {
            if !appState.selectedURLs.contains(item.url) { appState.selectedURLs = [item.url] }
            appState.symlinkItem = item
        }
        Button("AirDrop...") {
            if let airDrop = NSSharingService(named: .sendViaAirDrop) {
                airDrop.perform(withItems: [item.url])
            }
        }
        Divider()
        Menu("Services") {
            let services = NSSharingService.sharingServices(forItems: [item.url])
            ForEach(services, id: \.title) { service in
                Button(service.title) {
                    service.perform(withItems: [item.url])
                }
            }
        }
        Button("\(appState.tr(.properties)) (Cmd+I)") {
            if !appState.selectedURLs.contains(item.url) { appState.selectedURLs = [item.url] }
            appState.propertiesItem = item
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
        } else if flags.contains(.shift), let last = selectedURLs.first, let lastIdx = items.firstIndex(where: { $0.url == last }), let curIdx = items.firstIndex(where: { $0.url == item.url }) {
            let range = min(lastIdx, curIdx)...max(lastIdx, curIdx)
            let rangeURLs = items[range].map { $0.url }
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
                    try? FileSystemService.moveItem(at: droppedURL, toFolder: targetFolder)
                    self.refreshCurrentDirectory()
                }
            }
        }
    }
}
