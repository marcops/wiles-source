import SwiftUI
import UniformTypeIdentifiers

public struct FileItemInteractionsModifier: ViewModifier {
    let item: FileItem
    var appState: AppState
    let onRightClick: (() -> Void)?
    let onSelect: (() -> Void)?
    var onTargetedChanged: (Bool) -> Void

    @Environment(WindowUIState.self)
    private var windowUIState
    /// Clicking an already-selected item should trigger rename, like Finder's "slow double-click" —
    /// but a genuine fast double-click (which opens the item) also re-fires this same single-tap
    /// handler for its second click, so a naive delay would pop up rename right after navigating
    /// away. Bumping this counter in the double-click handler invalidates any rename scheduled by
    /// the click that was actually part of it, regardless of which handler happens to run first —
    /// both fire synchronously within the same gesture-recognition pass, well before the delay below
    /// elapses.
    @State private var renameRequestGeneration = 0

    public init(
        item: FileItem,
        appState: AppState,
        onRightClick: (() -> Void)? = nil,
        onSelect: (() -> Void)? = nil,
        onTargetedChanged: @escaping (Bool) -> Void = { _ in }) {
        self.item = item
        self.appState = appState
        self.onRightClick = onRightClick
        self.onSelect = onSelect
        self.onTargetedChanged = onTargetedChanged
    }

    public func body(content: Content) -> some View {
        content
            .onTapGesture(count: 2) {
                renameRequestGeneration += 1
                appState.navigateTo(item.url)
            }
            .simultaneousGesture(
                TapGesture().onEnded {
                    let wasAlreadySelected = appState.selection.selectedURLs.count == 1 && appState.selection.selectedURLs.contains(item.url)
                    if let onSelect {
                        onSelect()
                    } else {
                        appState.handleSelection(for: item)
                    }
                    scheduleRenameIfAlreadySelected(wasAlreadySelected)
                })
            .onDrag {
                if !appState.selection.selectedURLs.contains(item.url) {
                    appState.selection.selectedURLs = [item.url]
                }
                // One provider per row, representing only this row's own file — an NSItemProvider
                // is a single drag item, so registering every selected URL's representation onto
                // one shared provider (the old code) can't actually transfer more than one file.
                return NSItemProvider(object: item.url as NSURL)
            }
            .springLoadedFolder(folderURL: item.url, isDirectory: item.isDirectory, appState: appState, onTargetedChanged: onTargetedChanged)
            .overlay(
                RightClickDetector {
                    if let onRightClick {
                        onRightClick()
                    } else if !appState.selection.selectedURLs.contains(item.url) {
                        appState.selection.selectedURLs = [item.url]
                    }
                })
            .fileItemContextMenu(for: item, appState: appState)
    }

    /// Clicking an item that's already the sole selection triggers rename after a short delay,
    /// matching Finder's "click, pause, click again" — the delay lets a genuine fast double-click
    /// (which opens the item instead) invalidate this via `renameRequestGeneration`.
    private func scheduleRenameIfAlreadySelected(_ wasAlreadySelected: Bool) {
        renameRequestGeneration += 1
        guard wasAlreadySelected else { return }
        let myGeneration = renameRequestGeneration
        Task {
            try? await Task.sleep(nanoseconds: AsyncDelayTokens.renameDelay)
            guard myGeneration == renameRequestGeneration else { return }
            windowUIState.renameItem = item
        }
    }
}

public extension View {
    func fileItemInteractions(
        item: FileItem,
        appState: AppState,
        onRightClick: (() -> Void)? = nil,
        onSelect: (() -> Void)? = nil,
        onTargetedChanged: @escaping (Bool) -> Void = { _ in }) -> some View {
        modifier(
            FileItemInteractionsModifier(
                item: item,
                appState: appState,
                onRightClick: onRightClick,
                onSelect: onSelect,
                onTargetedChanged: onTargetedChanged))
    }
}
