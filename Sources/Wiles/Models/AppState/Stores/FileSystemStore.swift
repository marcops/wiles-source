import Foundation
import Observation

@Observable
@MainActor
public final class FileSystemStore {
    public var items: [FileItem] = []
    public var isLoading: Bool = false
    /// Suppresses `items` refreshes while set — see `AppState.enterRenameForNewlyCreated`.
    public var renamingURL: URL?
    var refreshTask: Task<Void, Never>?
    private let directoryMonitor = DirectoryMonitor()
    /// The URL currently watched by `directoryMonitor` — lets `startDirectoryMonitoring` skip a
    /// redundant stop/start cycle when called again for the same folder.
    private var monitoredURL: URL?
    /// Last time an FSEvents-triggered refresh actually ran — debounces `directoryMonitor`'s
    /// callback. `kFSEventStreamCreateFlagFileEvents` (needed for per-file granularity) also fires
    /// on routine metadata churn a real, Finder-visited folder generates on its own (e.g.
    /// `.DS_Store` writes) — each refresh re-reads the folder's contents/attributes, which can
    /// itself nudge that same metadata, turning into a self-sustaining high-CPU refresh loop
    /// without this floor between triggers.
    private var lastMonitorTriggeredRefreshAt: Date = .distantPast
    private static let monitorRefreshDebounceInterval: TimeInterval = 0.5

    public let trash = TrashState()

    public init() { }

    /// Cancels the in-flight refresh and stops the directory monitor. `FileSystemStore` is
    /// per-window, so without this, closing a window mid-load left the detached refresh running to
    /// completion. Called from the owning window's `.onDisappear` — a synchronous `deinit` here
    /// can't safely touch `@MainActor`-isolated state under Swift 6 strict concurrency.
    public func tearDown() {
        refreshTask?.cancel()
        directoryMonitor.cancel()
        monitoredURL = nil
    }

    public func startDirectoryMonitoring(for url: URL, refreshHandler: @escaping @Sendable () -> Void) {
        guard url.isFileURL else { return }
        let std = url.standardizedFileURL
        guard std != monitoredURL else { return }
        monitoredURL = std
        directoryMonitor.start(path: std.path) { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                let now = Date()
                guard now.timeIntervalSince(self.lastMonitorTriggeredRefreshAt) >= Self.monitorRefreshDebounceInterval else { return }
                self.lastMonitorTriggeredRefreshAt = now
                refreshHandler()
            }
        }
    }
}
