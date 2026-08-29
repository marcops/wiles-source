import Foundation
import GitBeacon

public extension AppState {
    func columnWidth(for column: ListColumn) -> CGFloat {
        preferences.columnStatesByColumn[column]?.width ?? column.defaultWidth
    }

    func isColumnVisible(_ column: ListColumn) -> Bool {
        preferences.columnStatesByColumn[column]?.isVisible ?? true
    }

    /// - Parameter persist: When `false` (e.g. while a resize drag is still in progress), the width
    ///   update is applied without triggering `PreferencesStore.saveListColumnStates()`'s synchronous
    ///   encode + write. Callers driving high-frequency updates (drag deltas) must call
    ///   `preferences.saveListColumnStates()` once when the interaction ends.
    func setColumnWidth(_ column: ListColumn, width: CGFloat, persist: Bool = true) {
        guard let idx = preferences.listColumnStates.firstIndex(where: { $0.column == column }) else { return }
        let applyWidth = { self.preferences.listColumnStates[idx].width = max(LayoutTokens.columnMinWidth, width) }
        if persist {
            applyWidth()
        } else {
            preferences.withColumnStatePersistenceSuppressed(applyWidth)
        }
    }

    func autoFitColumnWidth(_ column: ListColumn) {
        let newWidth = ColumnAutoFitService.calculateAutoFitWidth(
            for: column,
            items: fileSystem.items,
            iconSize: preferences.iconSize,
            language: preferences.appLanguage)
        setColumnWidth(column, width: newWidth)
    }

    func toggleColumnVisibility(_ column: ListColumn) {
        guard !column.isAlwaysVisible,
              let idx = preferences.listColumnStates.firstIndex(where: { $0.column == column }) else { return }
        preferences.listColumnStates[idx].isVisible.toggle()
    }

    /// The view mode for the currently browsed folder — respects `perFolderViewModeEnabled`.
    var currentViewMode: ViewMode {
        viewModeForFolder(navigation.currentURL)
    }

    func viewModeForFolder(_ url: URL) -> ViewMode {
        guard preferences.perFolderViewModeEnabled else { return preferences.viewMode }
        if let raw = preferences.perFolderViewModes[url.standardizedFileURL.path], let mode = ViewMode(rawValue: raw) {
            return mode
        }
        return preferences.viewMode
    }

    /// Moves the per-folder view-mode key when a folder is relocated in-app (Finder moves still orphan it).
    func remapPerFolderViewMode(from oldURL: URL, to newURL: URL) {
        let oldKey = oldURL.standardizedFileURL.path
        guard let raw = preferences.perFolderViewModes[oldKey] else { return }
        preferences.perFolderViewModes[oldKey] = nil
        preferences.perFolderViewModes[newURL.standardizedFileURL.path] = raw
    }

    func setViewModeForFolder(_ mode: ViewMode, for url: URL) {
        guard preferences.perFolderViewModeEnabled else {
            preferences.viewMode = mode
            return
        }
        preferences.perFolderViewModes[url.standardizedFileURL.path] = mode.rawValue
        preferences.viewMode = mode
    }

    func performImageConversion(
        item: FileItem,
        targetFormat: ImageFormat,
        preset: ResizePreset,
        cropPreset: CropPreset,
        quality: Double) {
        let sourceURL = item.url
        runDetachedURLOperation(context: "Converting image", operation: {
            try ImageConverterService.convertImage(
                at: sourceURL,
                targetFormat: targetFormat,
                preset: preset,
                cropPreset: cropPreset,
                quality: quality)
        }, recordUndo: { .createFile(url: $0) })
    }

    func performRename(item: FileItem, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != item.name else { return }
        let oldURL = item.url
        runDetachedURLOperation(context: "Renaming item", operation: {
            try await FileSystemService.renameItem(at: oldURL, newName: trimmed)
        }, recordUndo: { .rename(oldURL: oldURL, newURL: $0) })
    }

    func performBatchRename(items: [FileItem], mode: BatchRenameMode) {
        Task(priority: .userInitiated) { @MainActor [weak self] in
            do {
                let result = try await BatchRenameService.performBatchRename(items: items, mode: mode)
                guard let self else { return }
                for pair in result.renamedPairs {
                    undoRedoService.recordAction(.rename(oldURL: pair.old, newURL: pair.new))
                }
                refreshCurrentDirectory()
                selection.selectedURLs = Set(result.renamedURLs)
                if let message = result.failureSummaryMessage {
                    showError(message)
                }
            } catch {
                ErrorReporter.report(error, context: "Batch renaming items")
                self?.showError(error)
            }
        }
    }
}
