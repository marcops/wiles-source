import Foundation

extension AppState {
    func saveListColumnStates() {
        if let data = try? JSONEncoder().encode(listColumnStates) {
            UserDefaults.standard.set(data, forKey: DefaultsKey.listColumnStates.rawValue)
        }
    }

    public func columnWidth(for column: ListColumn) -> CGFloat {
        listColumnStates.first { $0.column == column }?.width ?? column.defaultWidth
    }

    public func isColumnVisible(_ column: ListColumn) -> Bool {
        listColumnStates.first { $0.column == column }?.isVisible ?? true
    }

    public func setColumnWidth(_ column: ListColumn, width: CGFloat) {
        guard let idx = listColumnStates.firstIndex(where: { $0.column == column }) else { return }
        listColumnStates[idx].width = max(LayoutTokens.columnMinWidth, width)
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
        return viewMode
    }

    public func setViewModeForFolder(_ mode: ViewMode, for url: URL) {
        perFolderViewModes[url.standardizedFileURL.path] = mode.rawValue
        self.viewMode = mode
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
        do {
            let newURLs = try BatchRenameService.performBatchRename(items: items, mode: mode)
            self.refreshCurrentDirectory()
            self.selectedURLs = Set(newURLs)
        } catch {
            self.showError(error.localizedDescription)
        }
    }

}
