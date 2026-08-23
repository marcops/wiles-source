import Foundation
import GitBeacon

public extension AppState {
    func updateTrashSize() {
        fileSystem.trash.refreshSize()
    }

    func performEmptyTrash() {
        fileSystem.trash.emptyTrash { [weak self] failedCount in
            guard let self else { return }
            updateTrashSize()
            refreshCurrentDirectory()
            if failedCount > 0 {
                showError(String(format: tr(.emptyTrashDeleteFailed), failedCount))
            }
        }
    }
}
