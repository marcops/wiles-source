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
        if !persist {
            preferences.suppressColumnStatePersistence = true
        }
        defer {
            if !persist {
                preferences.suppressColumnStatePersistence = false
            }
        }
        preferences.listColumnStates[idx].width = max(LayoutTokens.columnMinWidth, width)
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
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let newURL = try ImageConverterService.convertImage(
                    at: item.url,
                    targetFormat: targetFormat,
                    preset: preset,
                    cropPreset: cropPreset,
                    quality: quality)
                // A CI toolchain version needs these qualified explicitly inside this nested
                // weak-self closure even though this one compiles fine unqualified locally —
                // don't let swiftformat's --self remove strip them back out.
                // swiftformat:disable redundantSelf
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.undoRedoService.recordAction(.createFile(url: newURL))
                    self.refreshCurrentDirectory()
                    self.selection.selectedURLs = [newURL]
                }
                // swiftformat:enable redundantSelf
            } catch {
                ErrorReporter.report(error, context: "Converting image")
                // swiftformat:disable redundantSelf
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.showError(error)
                }
                // swiftformat:enable redundantSelf
            }
        }
    }

    func performRename(item: FileItem, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != item.name else { return }
        Task {
            do {
                let newURL = try await FileSystemService.renameItem(at: item.url, newName: trimmed)
                undoRedoService.recordAction(.rename(oldURL: item.url, newURL: newURL))
                refreshCurrentDirectory()
                selection.selectedURLs = [newURL]
            } catch {
                ErrorReporter.report(error, context: "Renaming item")
                showError(error)
            }
        }
    }

    func performBatchRename(items: [FileItem], mode: BatchRenameMode) {
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let result = try await BatchRenameService.performBatchRename(items: items, mode: mode)
                // swiftformat:disable redundantSelf
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    for pair in result.renamedPairs {
                        self.undoRedoService.recordAction(.rename(oldURL: pair.old, newURL: pair.new))
                    }
                    self.refreshCurrentDirectory()
                    self.selection.selectedURLs = Set(result.renamedURLs)
                    if let message = result.failureSummaryMessage {
                        self.showError(message)
                    }
                }
                // swiftformat:enable redundantSelf
            } catch {
                ErrorReporter.report(error, context: "Batch renaming items")
                // swiftformat:disable redundantSelf
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.showError(error)
                }
                // swiftformat:enable redundantSelf
            }
        }
    }
}
