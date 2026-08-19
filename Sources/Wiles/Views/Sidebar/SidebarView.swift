import AppKit
import SwiftUI

struct SidebarView: View {
    var appState: AppState
    @State private var rightClickedRowKey: String?
    @State private var renamingSmartFolderID: SmartFolder.ID?
    @State private var smartFolderRenameText: String = ""
    @FocusState private var isSmartFolderRenameFocused: Bool

    var devices: [SidebarItem] {
        let home = URL.userHome
        let cloudDocs = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        let airDrop = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app/Contents/Applications/AirDrop.app")
        let trashURL = URL.userTrash

        return [
            SidebarItem(name: appState.tr(.applications), iconName: "square.grid.3x3.fill", url: URL(fileURLWithPath: "/Applications")),
            SidebarItem(name: appState.tr(.airDrop), iconName: "dot.radiowaves.left.and.right", url: airDrop),
            SidebarItem(name: appState.tr(.iCloudDrive), iconName: "icloud.fill", url: cloudDocs),
            SidebarItem(name: "Macintosh HD", iconName: "internaldrive.fill", url: URL(fileURLWithPath: "/")),
            SidebarItem(name: appState.tr(.sidebarTrash), iconName: "trash.fill", url: trashURL)
        ]
    }

    var recentItems: [SidebarItem] {
        var seen = Set<URL>()
        var items: [SidebarItem] = []
        for url in appState.navigation.historyBack.reversed() {
            let std = url.standardizedFileURL
            if !seen.contains(std), std != appState.navigation.currentURL.standardizedFileURL {
                seen.insert(std)
                items.append(sidebarItem(for: std))
                if items.count >= LayoutTokens.maxRecentItemsCount {
                    break
                }
            }
        }
        return items
    }

    @State private var rootFolderNode: FolderNode?
    @State private var treeChildrenCache: [URL: [FolderNode]] = [:]

    var body: some View {
        @Bindable var appState = appState

        return GeometryReader { proxy in
            ScrollView([.vertical, .horizontal]) {
                VStack(alignment: .leading, spacing: 14) {
                    sidebarSectionsContent
                }
                .frame(minWidth: proxy.size.width, alignment: .leading)
                .padding(.top, LayoutTokens.sidebarTrafficLightInset)
                .padding(.bottom, 12)
            }
        }
        .frame(minWidth: LayoutTokens.sidebarMinWidth, idealWidth: LayoutTokens.sidebarIdealWidth, maxHeight: .infinity)
        .task {
            guard rootFolderNode == nil else { return }
            let node = await Task.detached(priority: .userInitiated) {
                FolderNode.buildRootTree()
            }.value
            rootFolderNode = node
        }
        .background(
            ZStack {
                TranslucentVisualEffectView(material: .sidebar)
                Color(NSColor.windowBackgroundColor)
                    .opacity(appState.preferences.sidebarOverlayOpacity)
            }
            .ignoresSafeArea())
        .overlay(alignment: .top) {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: LayoutTokens.sidebarDoubleClickZoneHeight)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    NSApp.keyWindow?.zoom(nil)
                }
        }
    }

    private var favoriteItems: [SidebarItem] {
        appState.preferences.favoriteURLs.map { sidebarItem(for: $0) }
    }

    private var networkAndCloudItems: [SidebarItem] {
        let networkShares = NetworkDiscoveryService.shared.discoveredShares.map {
            SidebarItem(name: $0.name, iconName: "network", url: $0.url)
        }
        var list = [SidebarItem(name: "Network", iconName: "network", url: URL(fileURLWithPath: "/Network"))]
        list.append(contentsOf: networkShares)
        return list
    }

    @ViewBuilder private var sidebarSectionsContent: some View {
        @Bindable var appState = appState

        if appState.preferences.showRecents {
            let recentsItem = SidebarItem(name: appState.tr(.recents), iconName: "clock.fill", url: AppState.recentsVirtualURL)
            sidebarRow(for: recentsItem, sectionKey: "Recents")
        }
        if appState.preferences.showFavorites, !favoriteItems.isEmpty {
            collapsibleSection(
                title: appState.tr(.favorites), identifierKey: "FAVORITES",
                isExpanded: $appState.preferences.isFavoritesExpanded, items: favoriteItems, isFavoritesSection: true)
        }
        if appState.preferences.showNetworkAndCloud {
            collapsibleSection(
                title: appState.tr(.networkAndCloud), identifierKey: "NETWORK",
                isExpanded: $appState.preferences.isNetworkExpanded, items: networkAndCloudItems, isFavoritesSection: false)
        }
        if appState.preferences.showPlaces {
            collapsibleSection(
                title: appState.tr(.places), identifierKey: "PLACES",
                isExpanded: $appState.preferences.isDevicesExpanded, items: devices, isFavoritesSection: false)
        }
        if appState.preferences.showDirectoryTree {
            directoryTreeSection(isExpanded: $appState.preferences.isTreeExpanded)
        }
        if appState.preferences.showTags {
            tagsSection(isExpanded: $appState.preferences.isTagsExpanded)
        }
        if !appState.smartFolders.isEmpty {
            smartFoldersSection(isExpanded: $appState.preferences.isSmartFoldersExpanded)
        }
    }

    private func directoryTreeSection(isExpanded: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if appState.preferences.showSidebarSectionTitles {
                sectionHeader(title: appState.tr(.directoryTree), identifierKey: "DIRECTORY_TREE", isExpanded: isExpanded)
            }
            if !appState.preferences.showSidebarSectionTitles || appState.preferences.isTreeExpanded {
                if let rootFolderNode {
                    DirectoryTreeNodeView(node: rootFolderNode, depth: 0, appState: appState, childrenCache: $treeChildrenCache)
                } else {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.horizontal, 12)
                }
            }
        }
    }

    private func tagsSection(isExpanded: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if appState.preferences.showSidebarSectionTitles {
                sectionHeader(title: appState.tr(.tags), identifierKey: "TAGS", isExpanded: isExpanded)
            }
            if !appState.preferences.showSidebarSectionTitles || appState.preferences.isTagsExpanded {
                tagRow(tag: "Red", colorKey: .red)
                tagRow(tag: "Orange", colorKey: .orange)
                tagRow(tag: "Yellow", colorKey: .yellow)
                tagRow(tag: "Green", colorKey: .green)
                tagRow(tag: "Blue", colorKey: .blue)
                tagRow(tag: "Purple", colorKey: .purple)
                tagRow(tag: "Gray", colorKey: .gray)
            }
        }
    }

    private func smartFoldersSection(isExpanded: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if appState.preferences.showSidebarSectionTitles {
                sectionHeader(title: appState.tr(.smartFolders), identifierKey: "SMART_FOLDERS", isExpanded: isExpanded)
            }
            if !appState.preferences.showSidebarSectionTitles || appState.preferences.isSmartFoldersExpanded {
                ForEach(appState.smartFolders) { folder in
                    smartFolderRow(folder: folder)
                }
            }
        }
    }

    /// `identifierKey` is a fixed, non-localized key (e.g. "FAVORITES") kept separate from the
    /// localized `title` shown on screen — accessibility identifiers must stay stable across
    /// languages so UI tests and automation don't break when the OS language changes.
    /// See AGENTS.md rule 33: a real `Button` on macOS does not reliably honor `.contentShape` for
    /// composite (icon + text) label content, so this uses a plain view + `.onTapGesture` instead.
    private func sectionHeader(title: String, identifierKey: String, isExpanded: Binding<Bool>) -> some View {
        HStack(spacing: 4) {
            Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 12)
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(MotionTokens.quickEase) {
                isExpanded.wrappedValue.toggle()
            }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("Section_\(identifierKey)")
        .accessibilityLabel(title)
        .accessibilityHint(appState.tr(.folder))
    }

    private func tagRow(tag: String, colorKey: L10n.Key) -> some View {
        let query = "tag:\(tag.lowercased())"
        let isSel = appState.searchQuery.lowercased() == query
        return Button {
            if isSel {
                appState.searchQuery = ""
            } else {
                appState.searchQuery = query
            }
        } label: {
            HStack(spacing: 10) {
                Circle().fill(colorForTag(tag)).frame(width: 10, height: 10).frame(width: 20, height: 20)
                Text(appState.tr(colorKey))
                    .font(.system(size: 13, weight: isSel ? .semibold : .regular, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(isSel ? Color.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }

    private func collapsibleSection(
        title: String,
        identifierKey: String,
        isExpanded: Binding<Bool>,
        items: [SidebarItem],
        isFavoritesSection: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if appState.preferences.showSidebarSectionTitles {
                sectionHeader(title: title, identifierKey: identifierKey, isExpanded: isExpanded)
            }
            if !appState.preferences.showSidebarSectionTitles || isExpanded.wrappedValue {
                ForEach(items) { item in
                    sidebarRow(for: item, sectionKey: title, isFavoritesSection: isFavoritesSection)
                }
            }
        }
    }

    private func sidebarItem(for url: URL) -> SidebarItem {
        let home = URL.userHome.standardizedFileURL
        let std = url.standardizedFileURL
        let path = std.path

        if url == AppState.recentsVirtualURL || std.absoluteString == AppState.recentsVirtualURL.absoluteString {
            return SidebarItem(name: appState.tr(.recents), iconName: "clock.fill", url: std)
        }
        if let wellKnown = wellKnownSidebarInfo(forPath: path, home: home) {
            return SidebarItem(name: wellKnown.name, iconName: wellKnown.icon, url: std)
        }
        let name = std.lastPathComponent.isEmpty ? "/" : std.lastPathComponent
        return SidebarItem(name: name, iconName: "folder.fill", url: std)
    }

    private func wellKnownSidebarInfo(forPath path: String, home: URL) -> (name: String, icon: String)? {
        switch path {
        case home.path: (appState.tr(.home), "house.fill")
        case home.appendingPathComponent("Desktop").path: (appState.tr(.desktop), "desktopcomputer")
        case home.appendingPathComponent("Documents").path: (appState.tr(.sidebarDocuments), "doc.fill")
        case home.appendingPathComponent("Downloads").path: (appState.tr(.downloads), "arrow.down.circle.fill")
        case "/Applications": (appState.tr(.applications), "square.grid.3x3.fill")
        case home.appendingPathComponent("Music").path: (appState.tr(.music), "music.note")
        case home.appendingPathComponent("Pictures").path: (appState.tr(.pictures), "photo.fill")
        case home.appendingPathComponent("Movies").path: (appState.tr(.movies), "film.fill")
        case home.appendingPathComponent(".Trash").path: (appState.tr(.sidebarTrash), "trash.fill")
        case "/": ("Macintosh HD", "internaldrive.fill")
        default: nil
        }
    }

    @ViewBuilder
    private func smartFolderRow(folder: SmartFolder) -> some View {
        if renamingSmartFolderID == folder.id {
            smartFolderRenameField(folder: folder)
        } else {
            smartFolderButtonRow(folder: folder)
        }
    }

    /// See AGENTS.md rule 33: a real `Button` on macOS does not reliably honor `.contentShape`
    /// for composite (icon + text) label content, so this uses a plain view + `.onTapGesture`.
    private func smartFolderButtonRow(folder: SmartFolder) -> some View {
        let isSel = appState.smartFolder.activeFolderID == folder.id
        return HStack(spacing: 10) {
            Image(systemName: folder.icon)
                .font(.system(size: 15))
                .foregroundColor(.accentColor)
                .frame(width: 20, height: 20)
            Text(folder.name)
                .font(.system(size: 13, weight: isSel ? .semibold : .regular))
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(isSel ? Color.accentColor.opacity(0.18) : Color.clear)
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            runSmartFolder(folder)
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(folder.name)
        .accessibilityHint(appState.tr(.folder))
        .padding(.horizontal, 8)
        .contextMenu {
            Button(appState.tr(.rename)) {
                smartFolderRenameText = folder.name
                renamingSmartFolderID = folder.id
            }
            Button(appState.tr(.updateSmartFolderSearch)) {
                appState.updateSmartFolderQuery(folder, to: appState.searchQuery)
            }
            .disabled(appState.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty)
            Divider()
            Button(appState.tr(.moveToTrash), role: .destructive) {
                appState.removeSmartFolder(folder)
            }
        }
    }

    private func smartFolderRenameField(folder: SmartFolder) -> some View {
        HStack(spacing: 10) {
            Image(systemName: folder.icon)
                .font(.system(size: 15))
                .foregroundColor(.accentColor)
                .frame(width: 20, height: 20)
            TextField("", text: $smartFolderRenameText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isSmartFolderRenameFocused)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + AsyncDelayTokens.searchFieldFocusDelay) {
                        isSmartFolderRenameFocused = true
                    }
                }
                .onSubmit { commitSmartFolderRename(folder) }
                .onExitCommand { renamingSmartFolderID = nil }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .padding(.horizontal, 8)
        .onChange(of: isSmartFolderRenameFocused) { _, focused in
            if !focused {
                commitSmartFolderRename(folder)
            }
        }
    }

    private func commitSmartFolderRename(_ folder: SmartFolder) {
        guard renamingSmartFolderID == folder.id else { return }
        appState.renameSmartFolder(folder, to: smartFolderRenameText)
        renamingSmartFolderID = nil
    }

    private func runSmartFolder(_ folder: SmartFolder) {
        appState.prepareForSmartFolderRun(folder)
        SmartFolderService.shared.executeQuery(for: folder) { items in
            Task { @MainActor in
                appState.fileSystem.items = items
            }
        }
    }

    private func sidebarRow(for item: SidebarItem, sectionKey: String, isFavoritesSection: Bool = false) -> some View {
        let rowKey = "\(sectionKey)|\(item.url.path)"
        return SidebarRowView(
            item: item,
            appState: appState,
            isFavoritesSection: isFavoritesSection,
            isRightClicked: rightClickedRowKey == rowKey,
            isAnotherRowRightClicked: rightClickedRowKey != nil && rightClickedRowKey != rowKey,
            onRightClick: { rightClickedRowKey = rowKey },
            onLeftClick: { rightClickedRowKey = nil })
    }
}
