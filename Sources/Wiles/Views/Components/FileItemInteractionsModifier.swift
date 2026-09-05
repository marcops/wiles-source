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

    /// True when the grabbed row is one of several selected items — the case a single SwiftUI
    /// `NSItemProvider` can't carry, so `MultiFileDragView` takes over the drag.
    private var isMultiSelectionDrag: Bool {
        appState.selection.selectedURLs.count > 1 && appState.selection.selectedURLs.contains(item.url)
    }

    public func body(content: Content) -> some View {
        content
            .onTapGesture(count: 2) { handleDoubleTap() }
            .simultaneousGesture(TapGesture().onEnded { handleSingleTap() })
            .onDrag {
                if !appState.selection.selectedURLs.contains(item.url) {
                    appState.selection.selectedURLs = [item.url]
                }
                // Single-item fallback: one NSItemProvider carries one file. The multi-selection
                // case is handled by the MultiFileDragView overlay below (one drag item per URL).
                return NSItemProvider(object: item.url as NSURL)
            }
            .springLoadedFolder(folderURL: item.url, isDirectory: item.isDirectory, appState: appState, onTargetedChanged: onTargetedChanged)
            .overlay(multiSelectionDragOverlay)
            .overlay(
                RightClickDetector {
                    // Always land `item` in the selection before the context menu opens, so every
                    // menu action can just read `appState.selection.selectedURLs` (see
                    // `SharedFileItemContextMenu`) — no per-action "ensure selected" dance.
                    if !appState.selection.selectedURLs.contains(item.url) {
                        appState.selection.selectedURLs = [item.url]
                    }
                    onRightClick?()
                })
            .fileItemContextMenu(for: item, appState: appState)
    }

    /// Left-mouse drag source for a multi-selection; inert (passes clicks/right-clicks through) for
    /// a single selection. `onClick`/`onDoubleClick` mirror the SwiftUI tap handlers for the case a
    /// press never becomes a drag.
    @ViewBuilder private var multiSelectionDragOverlay: some View {
        if isMultiSelectionDrag {
            MultiFileDragView(
                isActive: true,
                draggedURLs: Array(appState.selection.selectedURLs),
                dragImage: item.icon,
                onClick: { handleSingleTap() },
                onDoubleClick: { handleDoubleTap() })
        }
    }

    private func handleDoubleTap() {
        renameRequestGeneration += 1
        if ArchiveService.isArchive(url: item.url) {
            windowUIState.activeModal = .inspectArchive(item.url)
        } else {
            appState.openItem(item.url)
        }
    }

    private func handleSingleTap() {
        let wasAlreadySelected = appState.selection.selectedURLs.count == 1 && appState.selection.selectedURLs.contains(item.url)
        if let onSelect {
            onSelect()
        } else {
            appState.handleSelection(for: item)
        }
        scheduleRenameIfAlreadySelected(wasAlreadySelected)
    }

    /// Clicking an item that's already the sole selection triggers rename after a short delay,
    /// matching Finder's "click, pause, click again" — the delay lets a genuine fast double-click
    /// (which opens the item instead) invalidate this via `renameRequestGeneration`.
    private func scheduleRenameIfAlreadySelected(_ wasAlreadySelected: Bool) {
        renameRequestGeneration += 1
        guard wasAlreadySelected else { return }
        let myGeneration = renameRequestGeneration
        Task {
            try? await Task.sleep(for: AsyncDelayTokens.renameDelay)
            guard Self.shouldEnterRename(
                scheduledGeneration: myGeneration,
                currentGeneration: renameRequestGeneration,
                selectedURLs: appState.selection.selectedURLs,
                itemURL: item.url,
                itemStillListed: appState.fileSystem.itemsByURL[item.url] != nil) else { return }
            windowUIState.renameItem = item
        }
    }

    /// The delayed "click, pause → rename" only fires if nothing changed during the pause. A
    /// keyboard navigation within `renameDelay` moves the selection (or leaves the folder) without
    /// touching `renameRequestGeneration`, so the generation check alone let a rename field open on
    /// an item no longer selected / no longer on screen, leaving `isTextFieldEditingActive` stuck
    /// Also require the item to still be the sole selection and still listed.
    static func shouldEnterRename(
        scheduledGeneration: Int, currentGeneration: Int,
        selectedURLs: Set<URL>, itemURL: URL, itemStillListed: Bool) -> Bool {
        scheduledGeneration == currentGeneration
            && selectedURLs == [itemURL]
            && itemStillListed
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
