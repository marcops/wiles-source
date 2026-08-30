import Foundation
import GitBeacon

public extension AppState {
    func columnWidth(for column: ListColumn) -> CGFloat {
        preferences.view.columnStatesByColumn[column]?.width ?? column.defaultWidth
    }

    func isColumnVisible(_ column: ListColumn) -> Bool {
        preferences.view.columnStatesByColumn[column]?.isVisible ?? true
    }

    /// - Parameter persist: When `false` (e.g. while a resize drag is still in progress), the width
    ///   update is applied without triggering `PreferencesStore.saveListColumnStates()`'s synchronous
    ///   encode + write. Callers driving high-frequency updates (drag deltas) must call
    ///   `preferences.view.saveListColumnStates()` once when the interaction ends.
    func setColumnWidth(_ column: ListColumn, width: CGFloat, persist: Bool = true) {
        guard let idx = preferences.view.listColumnStates.firstIndex(where: { $0.column == column }) else { return }
        let applyWidth = { self.preferences.view.listColumnStates[idx].width = max(LayoutTokens.columnMinWidth, width) }
        if persist {
            applyWidth()
        } else {
            preferences.view.withColumnStatePersistenceSuppressed(applyWidth)
        }
    }

    func autoFitColumnWidth(_ column: ListColumn) {
        let newWidth = ColumnAutoFitService.calculateAutoFitWidth(
            for: column,
            items: fileSystem.items,
            iconSize: preferences.view.iconSize,
            language: preferences.appearance.appLanguage)
        setColumnWidth(column, width: newWidth)
    }

    func toggleColumnVisibility(_ column: ListColumn) {
        guard !column.isAlwaysVisible,
              let idx = preferences.view.listColumnStates.firstIndex(where: { $0.column == column }) else { return }
        preferences.view.listColumnStates[idx].isVisible.toggle()
    }

    /// The view mode for the currently browsed folder — respects `perFolderViewModeEnabled`.
    var currentViewMode: ViewMode {
        viewModeForFolder(navigation.currentURL)
    }

    func viewModeForFolder(_ url: URL) -> ViewMode {
        guard preferences.view.perFolderViewModeEnabled else { return preferences.view.viewMode }
        if let raw = preferences.view.perFolderViewModes[url.standardizedFileURL.path], let mode = ViewMode(rawValue: raw) {
            return mode
        }
        return preferences.view.viewMode
    }

    /// Moves the per-folder view-mode key when a folder is relocated in-app (Finder moves still orphan it).
    func remapPerFolderViewMode(from oldURL: URL, to newURL: URL) {
        let oldKey = oldURL.standardizedFileURL.path
        guard let raw = preferences.view.perFolderViewModes[oldKey] else { return }
        preferences.view.perFolderViewModes[oldKey] = nil
        preferences.view.perFolderViewModes[newURL.standardizedFileURL.path] = raw
    }

    func setViewModeForFolder(_ mode: ViewMode, for url: URL) {
        guard preferences.view.perFolderViewModeEnabled else {
            preferences.view.viewMode = mode
            return
        }
        preferences.view.perFolderViewModes[url.standardizedFileURL.path] = mode.rawValue
        preferences.view.viewMode = mode
    }

    func performImageConversion(
        item: FileItem,
        targetFormat: ImageFormat,
        preset: ResizePreset,
        cropPreset: CropPreset,
        quality: Double) {
        let sourceURL = item.url
        runDetachedURLOperation(context: "Converting image", taskTitle: tr(.convertingImageEllipsis), operation: {
            try ImageConverterService.convertImage(
                at: sourceURL,
                targetFormat: targetFormat,
                preset: preset,
                cropPreset: cropPreset,
                quality: quality)
        }, recordUndo: { .createFile(url: $0) })
    }

    func performRename(item: FileItem, newName: String) {
        guard let sanitized = FilenameSanitizer.sanitize(newName), sanitized != item.name else { return }
        let oldURL = item.url
        runDetachedURLOperation(context: "Renaming item", operation: {
            try await FileSystemService.renameItem(at: oldURL, newName: sanitized)
        }, recordUndo: { .rename(oldURL: oldURL, newURL: $0) })
    }

    func performBatchRename(items: [FileItem], mode: BatchRenameMode) {
        runDetachedFileOperation(
            context: "Batch renaming items",
            taskTitle: tr(.batchRenamingEllipsis),
            onSuccess: { [weak self] (result: BatchRenameResult) in
                guard let self else { return }
                for pair in result.renamedPairs {
                    undoRedoService.recordAction(.rename(oldURL: pair.old, newURL: pair.new))
                }
                selection.selectedURLs = Set(result.renamedURLs)
                if let failureError = result.failureError {
                    showError(failureError)
                }
            },
            operation: { try await BatchRenameService.performBatchRename(items: items, mode: mode) })
    }
}
