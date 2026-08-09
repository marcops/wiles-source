import SwiftUI
import AppKit

struct SidebarRowView: View {
    let item: SidebarItem
    var appState: AppState
    @Environment(WindowUIState.self)
    private var windowUIState
    let isFavoritesSection: Bool
    let isRightClicked: Bool
    let isAnotherRowRightClicked: Bool
    let onRightClick: () -> Void
    let onLeftClick: () -> Void

    @State private var isDragTargeted = false

    @State private var isHovered = false

    var body: some View {
        let isCurrentFolder = appState.navigation.currentURL.standardizedFileURL == item.url.standardizedFileURL
        let isSel = isRightClicked || (isCurrentFolder && !isAnotherRowRightClicked)
        let isTrash = item.url.standardizedFileURL == URL.userTrash.standardizedFileURL
        // See AGENTS.md rule 33: a real `Button` on macOS does not reliably honor `.contentShape`
        // for composite (icon + text) label content, so this uses a plain view + `.onTapGesture`.
        return HStack(spacing: 10) {
            Image(systemName: item.iconName)
                .font(.system(size: 15)).foregroundColor(.accentColor).frame(width: 20)
            Text(item.name)
                .font(.system(size: 13, weight: isSel ? .semibold : .regular))
                .foregroundColor(.primary)
            Spacer()
            if isTrash {
                if appState.isTrashUpdating {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.mini)
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                } else if !appState.trashSizeString.isEmpty
                    && !["Zero KB", "0 KB", "0 bytes"].contains(appState.trashSizeString) {
                    Text(appState.trashSizeString)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(10)
                }
            }
            if item.url.path.hasPrefix("/Volumes/") && item.url.path != "/" {
                Button {
                    let target = item.url
                    do {
                        try NSWorkspace.shared.unmountAndEjectDevice(at: target)
                        appState.refreshCurrentDirectory()
                    } catch {
                        appState.showError(error.localizedDescription)
                    }
                } label: {
                    Image(systemName: "eject.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help(appState.tr(.ejectVolume))
                .accessibilityLabel(appState.tr(.ejectVolume))
                .accessibilityHint(appState.tr(.ejectVolume))
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(
            isDragTargeted ? Color.accentColor.opacity(0.25) :
            (isSel ? Color.accentColor.opacity(0.18) :
            (isHovered ? Color.primary.opacity(0.06) : Color.clear))
        )
        .cornerRadius(8)
        .scaleEffect(isDragTargeted ? 1.02 : 1.0)
        .animation(MotionTokens.snappySpring, value: isDragTargeted)
        .animation(MotionTokens.quickEase, value: isHovered)
        .contentShape(Rectangle())
        .onTapGesture {
            onLeftClick()
            appState.navigateTo(item.url)
            windowUIState.selectedFavoriteURL = isFavoritesSection ? item.url : nil
        }
        .padding(.horizontal, 8)
        .accessibilityAddTraits(isSel ? [.isButton, .isSelected] : [.isButton])
        .accessibilityIdentifier(item.name)
        .accessibilityLabel(item.name)
        .accessibilityHint(appState.tr(.folder))
        .onHover { isHovered = $0 }
        .overlay(
            RightClickDetector { onRightClick() }
        )
        .springLoadedFolder(folderURL: item.url, isDirectory: true, appState: appState) { targeted in
            withAnimation(MotionTokens.quickEase) { isDragTargeted = targeted }
        }
        .contextMenu {
            Button(appState.tr(.open)) { appState.navigateTo(item.url) }
            Menu(appState.tr(.copyPath)) {
                Button(appState.tr(.copyPathAbsolute)) {
                    CopyPathService.copy(urls: [item.url], variant: .absolute)
                }
                Button(appState.tr(.copyPathRelative)) {
                    CopyPathService.copy(urls: [item.url], variant: .relative, relativeTo: appState.navigation.currentURL)
                }
                Button(appState.tr(.copyPathURL)) {
                    CopyPathService.copy(urls: [item.url], variant: .fileURL)
                }
                Button(appState.tr(.copyPathTerminal)) {
                    CopyPathService.copy(urls: [item.url], variant: .terminalEscaped)
                }
            }
            Divider()
            if isFavoritesSection || appState.isFavorite(item.url) {
                Button(appState.tr(.removeFromFavorites)) {
                    appState.removeFavorite(item.url)
                }
            } else {
                Button(appState.tr(.addToFavorites)) {
                    appState.addFavorite(item.url)
                }
            }
            Divider()
            Button("\(appState.tr(.properties)) (Cmd+I)") {
                let fileItem = FileItem(url: item.url, icon: NSWorkspace.shared.icon(forFile: item.url.path))
                windowUIState.propertiesItem = fileItem
            }
            if isTrash {
                Divider()
                Button("\(appState.tr(.emptyTrash))...") {
                    windowUIState.showEmptyTrashAlert = true
                }
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider], targetFolder: URL) {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url else { return }
                Task { @MainActor in
                    do {
                        _ = try appState.moveItem(at: url, toFolder: targetFolder)
                        appState.refreshCurrentDirectory()
                    } catch {
                        appState.showError(error)
                    }
                }
            }
        }
    }
}
