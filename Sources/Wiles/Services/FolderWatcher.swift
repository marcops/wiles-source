import Foundation
import GitBeacon

/// Watches a set of folders for filesystem write activity via `DispatchSource`, debouncing
/// rapid-fire events on the same folder into a single `onChange` callback once activity settles.
/// Generic over what "change" means to the caller — it only reports "this folder changed,"
/// decoupled from any matching/dispatch logic that decides what to do about it.
@MainActor
final class FolderWatcher {
    private var fileMonitors: [String: any DispatchSourceFileSystemObject] = [:]
    /// Debounces rapid-fire `.write` events on a watched folder (e.g. a browser writing a large
    /// download incrementally can fire this thousands of times) into a single `onChange` call
    /// after activity settles, instead of firing once per write.
    private var pendingScans: [String: DispatchWorkItem] = [:]
    private let debounceInterval: TimeInterval

    /// Invoked (debounced) on the main queue whenever a watched folder receives a `.write` event.
    var onChange: ((URL) -> Void)?

    init(debounceInterval: TimeInterval) {
        self.debounceInterval = debounceInterval
    }

    /// Replaces the current set of watched folders: stops all existing watchers and pending
    /// debounced scans, then starts a fresh `DispatchSource` watcher for each folder in `folders`.
    func watch(folders: Set<URL>) {
        stopAll()
        for folder in folders {
            startWatching(folder: folder)
        }
    }

    private func stopAll() {
        // Each source's cancel handler (set in `startWatching`) closes its own fd once the
        // cancellation completes asynchronously on the source's queue. Closing here too would
        // double-close the fd, risking a close of an unrelated fd the OS has since reused.
        for (_, source) in fileMonitors {
            source.cancel()
        }
        fileMonitors.removeAll()
        for (_, workItem) in pendingScans {
            workItem.cancel()
        }
        pendingScans.removeAll()
    }

    private func startWatching(folder: URL) {
        let fd = open(folder.path, O_EVTONLY)
        guard fd != -1 else {
            ErrorReporter.report(
                NSError(domain: NSPOSIXErrorDomain, code: Int(errno)),
                context: "FolderWatcher: open(O_EVTONLY) failed for \(folder.path); this folder will not be watched")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .write, queue: .main)

        source.setEventHandler { [weak self] in
            self?.scheduleCallback(for: folder)
        }

        source.setCancelHandler {
            close(fd)
        }

        fileMonitors[folder.path] = source
        source.resume()
    }

    /// Coalesces repeated events for the same folder into one `onChange` call, resetting the timer
    /// on every new event — so a folder that's still actively changing keeps pushing the callback
    /// back instead of firing one per event. Also callable directly (bypassing an actual filesystem
    /// event) to trigger the same debounced-callback path.
    func scheduleCallback(for folder: URL) {
        pendingScans[folder.path]?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.onChange?(folder)
        }
        pendingScans[folder.path] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
    }
}
