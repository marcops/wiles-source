import Foundation

/// One gather-only `NSMetadataQuery` pass, wrapped so callers get a plain `async` call with
/// guaranteed observer/timeout teardown instead of juggling notification tokens by hand.
@MainActor
final class SpotlightQuery {
    private let query = NSMetadataQuery()
    private var observer: (any NSObjectProtocol)?
    private var timeoutTask: Task<Void, Never>?
    private var continuation: CheckedContinuation<(paths: [String], timedOut: Bool), Never>?

    /// Backstop for `NSMetadataQueryDidFinishGathering` never firing — on a volume without
    /// Spotlight indexing (an SMB share, an external drive with indexing off) the query gathers
    /// forever, so without this the caller would await it indefinitely.
    static let defaultTimeout: Duration = .seconds(20)
    private let timeout: Duration

    init(predicate: NSPredicate, searchScopes: [Any], timeout: Duration = SpotlightQuery.defaultTimeout) {
        query.predicate = predicate
        query.searchScopes = searchScopes
        self.timeout = timeout
    }

    /// Gathers once, then resolves with the matching file paths — empty on timeout or if abandoned
    /// via `cancel()`. `timedOut` is `true` only when the gather never finished (an unindexed
    /// volume), so a caller can tell that apart from a genuine zero-match result.
    func run() async -> (paths: [String], timedOut: Bool) {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            observer = NotificationCenter.default.addObserver(
                forName: .NSMetadataQueryDidFinishGathering, object: query, queue: .main) { notification in
                    // `NSMetadataQuery`/`Notification` aren't Sendable — pull the plain paths out here,
                    // then hop once for the `self`-touching teardown.
                    let paths = Self.paths(from: notification)
                    Task { @MainActor [weak self] in self?.complete(with: paths) }
                }
            query.start()
            timeoutTask = Task { [weak self, timeout] in
                try? await Task.sleep(for: timeout)
                guard !Task.isCancelled else { return }
                self?.complete(with: [], timedOut: true)
            }
        }
    }

    /// Abandons an in-flight gather; the pending `run()` resolves to `[]`.
    func cancel() {
        complete(with: [])
    }

    /// Resume-once plus teardown. Safe to call from the gather notification, the timeout, or `cancel()`.
    private func complete(with paths: [String], timedOut: Bool = false) {
        guard let continuation else { return }
        self.continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
        query.stop()
        continuation.resume(returning: (paths, timedOut))
    }

    private nonisolated static func paths(from notification: Notification) -> [String] {
        guard let query = notification.object as? NSMetadataQuery,
              let results = query.results as? [NSMetadataItem] else { return [] }
        query.stop()
        return results.compactMap { $0.value(forAttribute: NSMetadataItemPathKey) as? String }
    }
}
