import Foundation
import GitBeacon

public extension AppState {
    func columnWidth(for column: ListColumn) -> CGFloat {
        preferences.listColumnStates.first { $0.column == column }?.width ?? column.defaultWidth
    }

    func isColumnVisible(_ column: ListColumn) -> Bool {
        preferences.listColumnStates.first { $0.column == column }?.isVisible ?? true
    }

    /// - Parameter persist: When `false` (e.g. while a resize drag is still in progress), the width
    ///   update is applied without triggering `PreferencesStore.saveListColumnStates()`'s synchronous
    ///   encode + write. Callers driving high-frequency updates (drag deltas) must call
    ///   `persistColumnWidths()` once when the interaction ends.
    func setColumnWidth(_ column: ListColumn, width: CGFloat, persist: Bool = true) {
        guard let idx = preferences.listColumnStates.firstIndex(where: { $0.column == column }) else { return }
        if !persist {
            preferences.suppressColumnStatePersistence = true
        }
        preferences.listColumnStates[idx].width = max(LayoutTokens.columnMinWidth, width)
        if !persist {
            preferences.suppressColumnStatePersistence = false
        }
    }

    /// Persists the current `listColumnStates` once. Call this at the end of a high-frequency
    /// interaction (drag end) that used `setColumnWidth(_:width:persist: false)` throughout.
    func persistColumnWidths() {
        preferences.saveListColumnStates()
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

    func viewModeForFolder(_ url: URL) -> ViewMode {
        if let raw = preferences.perFolderViewModes[url.standardizedFileURL.path], let mode = ViewMode(rawValue: raw) {
            return mode
        }
        return preferences.viewMode
    }

    func setViewModeForFolder(_ mode: ViewMode, for url: URL) {
        preferences.perFolderViewModes[url.standardizedFileURL.path] = mode.rawValue
        preferences.viewMode = mode
    }

    func performImageConversion(
        item: FileItem,
        targetFormat: ImageFormat,
        preset: ResizePreset,
        cropPreset: CropPreset,
        quality: Double) {
        Task.detached(priority: .userInitiated) {
            do {
                let newURL = try ImageConverterService.convertImage(
                    at: item.url,
                    targetFormat: targetFormat,
                    preset: preset,
                    cropPreset: cropPreset,
                    quality: quality)
                await MainActor.run {
                    self.refreshCurrentDirectory()
                    self.selectedURLs = [newURL]
                }
            } catch {
                ErrorReporter.report(error, context: "Converting image")
                await MainActor.run {
                    self.showError(error.localizedDescription)
                }
            }
        }
    }

    func performRename(item: FileItem, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != item.name else { return }
        do {
            let newURL = try FileSystemService.renameItem(at: item.url, newName: trimmed)
            undoRedoService.recordAction(.rename(oldURL: item.url, newURL: newURL))
            refreshCurrentDirectory()
            selectedURLs = [newURL]
        } catch {
            ErrorReporter.report(error, context: "Renaming item")
            showError(error.localizedDescription)
        }
    }

    func performBatchRename(items: [FileItem], mode: BatchRenameMode) {
        Task.detached(priority: .userInitiated) {
            do {
                let newURLs = try BatchRenameService.performBatchRename(items: items, mode: mode)
                await MainActor.run {
                    self.refreshCurrentDirectory()
                    self.selectedURLs = Set(newURLs)
                }
            } catch {
                ErrorReporter.report(error, context: "Batch renaming items")
                await MainActor.run {
                    self.showError(error.localizedDescription)
                }
            }
        }
    }
}
