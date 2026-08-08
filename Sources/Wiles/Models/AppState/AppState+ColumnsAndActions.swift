import Foundation
import os

private let columnPersistenceLogger = Logger(subsystem: "com.wiles.app", category: "ColumnPersistence")

extension AppState {
    func saveListColumnStates() {
        do {
            let data = try JSONEncoder().encode(listColumnStates)
            UserDefaults.standard.set(data, forKey: DefaultsKey.listColumnStates.rawValue)
        } catch {
            // Encoding failure here silently drops the user's column widths/visibility on next
            // launch (falls back to defaults) with no other signal, so log it for debugging.
            columnPersistenceLogger.error("Failed to encode listColumnStates: \(error.localizedDescription)")
        }
    }

    public func columnWidth(for column: ListColumn) -> CGFloat {
        listColumnStates.first { $0.column == column }?.width ?? column.defaultWidth
    }

    public func isColumnVisible(_ column: ListColumn) -> Bool {
        listColumnStates.first { $0.column == column }?.isVisible ?? true
    }

    /// - Parameter persist: When `false` (e.g. while a resize drag is still in progress), the width
    ///   update is applied without triggering `saveListColumnStates()`'s synchronous encode + write.
    ///   Callers driving high-frequency updates (drag deltas) must call `persistColumnWidths()` once
    ///   when the interaction ends.
    public func setColumnWidth(_ column: ListColumn, width: CGFloat, persist: Bool = true) {
        guard let idx = listColumnStates.firstIndex(where: { $0.column == column }) else { return }
        if !persist { suppressColumnStatePersistence = true }
        listColumnStates[idx].width = max(LayoutTokens.columnMinWidth, width)
        if !persist { suppressColumnStatePersistence = false }
    }

    /// Persists the current `listColumnStates` once. Call this at the end of a high-frequency
    /// interaction (drag end) that used `setColumnWidth(_:width:persist: false)` throughout.
    public func persistColumnWidths() {
        saveListColumnStates()
    }

    public func autoFitColumnWidth(_ column: ListColumn) {
        let newWidth = ColumnAutoFitService.calculateAutoFitWidth(for: column, in: self)
        setColumnWidth(column, width: newWidth)
    }

    public func toggleColumnVisibility(_ column: ListColumn) {
        guard !column.isAlwaysVisible,
              let idx = listColumnStates.firstIndex(where: { $0.column == column }) else { return }
        listColumnStates[idx].isVisible.toggle()
    }

    public func viewModeForFolder(_ url: URL) -> ViewMode {
        if let raw = perFolderViewModes[url.standardizedFileURL.path], let mode = ViewMode(rawValue: raw) {
            return mode
        }
        return preferences.viewMode
    }

    public func setViewModeForFolder(_ mode: ViewMode, for url: URL) {
        perFolderViewModes[url.standardizedFileURL.path] = mode.rawValue
        self.preferences.viewMode = mode
    }

    public func performImageConversion(
        item: FileItem,
        targetFormat: ImageFormat,
        preset: ResizePreset,
        cropPreset: CropPreset,
        quality: Double
    ) {
        Task.detached(priority: .userInitiated) {
            do {
                let newURL = try ImageConverterService.convertImage(
                    at: item.url,
                    targetFormat: targetFormat,
                    preset: preset,
                    cropPreset: cropPreset,
                    quality: quality
                )
                await MainActor.run {
                    self.refreshCurrentDirectory()
                    self.selectedURLs = [newURL]
                }
            } catch {
                await MainActor.run {
                    self.showError(error.localizedDescription)
                }
            }
        }
    }

    public func performRename(item: FileItem, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != item.name else { return }
        do {
            let newURL = try FileSystemService.renameItem(at: item.url, newName: trimmed)
            UndoRedoService.shared.recordAction(.rename(oldURL: item.url, newURL: newURL))
            self.refreshCurrentDirectory()
            self.selectedURLs = [newURL]
        } catch {
            self.showError(error.localizedDescription)
        }
    }

    public func performBatchRename(items: [FileItem], mode: BatchRenameMode) {
        Task.detached(priority: .userInitiated) {
            do {
                let newURLs = try BatchRenameService.performBatchRename(items: items, mode: mode)
                await MainActor.run {
                    self.refreshCurrentDirectory()
                    self.selectedURLs = Set(newURLs)
                }
            } catch {
                await MainActor.run {
                    self.showError(error.localizedDescription)
                }
            }
        }
    }

}
