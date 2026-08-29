import Foundation
import Observation

@Observable
@MainActor
public final class FileSystemStore {
    public var items: [FileItem] = [] {
        didSet { totalFileSizeBytes = items.reduce(0) { $0 + ($1.isDirectory ? 0 : $1.size) } }
    }

    /// Sum of every non-directory item's size, maintained on `items` assignment so the footer's
    /// `statusText` doesn't re-`reduce` over the whole (possibly 10k-entry) list on every render.
    public private(set) var totalFileSizeBytes: Int64 = 0
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
    /// without this floor between triggers. An event landing inside the window schedules one
    /// trailing-edge refresh at the window's end so the last change of a burst isn't dropped.
    private var lastMonitorTriggeredRefreshAt: Date = .distantPast
    private static let monitorRefreshDebounceInterval: TimeInterval = 0.5
    private var trailingRefreshTask: Task<Void, Never>?

    public let trash = TrashState()

    public init() { }

    /// Cancels the in-flight refresh and stops the directory monitor. `FileSystemStore` is
    /// per-window, so without this, closing a window mid-load left the detached refresh running to
    /// completion. Called from the owning window's `.onDisappear` — a synchronous `deinit` here
    /// can't safely touch `@MainActor`-isolated state under Swift 6 strict concurrency.
    public func tearDown() {
        refreshTask?.cancel()
        trailingRefreshTask?.cancel()
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
                self.handleMonitorEvent(refreshHandler: refreshHandler)
            }
        }
    }

    private func handleMonitorEvent(refreshHandler: @escaping @Sendable () -> Void) {
        let elapsed = Date().timeIntervalSince(lastMonitorTriggeredRefreshAt)
        if elapsed >= Self.monitorRefreshDebounceInterval {
            lastMonitorTriggeredRefreshAt = Date()
            refreshHandler()
            return
        }
        // Inside the cooldown: schedule one trailing refresh at the window's end (don't stack).
        guard trailingRefreshTask == nil else { return }
        trailingRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(Self.monitorRefreshDebounceInterval - elapsed))
            guard let self, !Task.isCancelled else { return }
            trailingRefreshTask = nil
            lastMonitorTriggeredRefreshAt = Date()
            refreshHandler()
        }
    }
}
