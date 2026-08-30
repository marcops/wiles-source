import Foundation

/// One gather-only `NSMetadataQuery` pass, wrapped so callers get a plain `async` call with
/// guaranteed observer/timeout teardown instead of juggling notification tokens by hand.
@MainActor
final class SpotlightQuery {
    private let query = NSMetadataQuery()
    private var observer: (any NSObjectProtocol)?
    private var timeoutTask: Task<Void, Never>?
    private var continuation: CheckedContinuation<[String], Never>?

    /// Backstop for `NSMetadataQueryDidFinishGathering` never firing — on a volume without
    /// Spotlight indexing (an SMB share, an external drive with indexing off) the query gathers
    /// forever, so without this the caller would await it indefinitely.
    private static let timeout: Duration = .seconds(20)

    init(predicate: NSPredicate, searchScopes: [Any]) {
        query.predicate = predicate
        query.searchScopes = searchScopes
    }

    /// Gathers once, then resolves with the matching file paths — empty on timeout or if abandoned
    /// via `cancel()`. Stops the query and removes the observer before returning either way.
    func run() async -> [String] {
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
            timeoutTask = Task { [weak self] in
                try? await Task.sleep(for: Self.timeout)
                guard !Task.isCancelled else { return }
                self?.complete(with: [])
            }
        }
    }

    /// Abandons an in-flight gather; the pending `run()` resolves to `[]`.
    func cancel() {
        complete(with: [])
    }

    /// Resume-once plus teardown. Safe to call from the gather notification, the timeout, or `cancel()`.
    private func complete(with paths: [String]) {
        guard let continuation else { return }
        self.continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
        query.stop()
        continuation.resume(returning: paths)
    }

    private nonisolated static func paths(from notification: Notification) -> [String] {
        guard let query = notification.object as? NSMetadataQuery,
              let results = query.results as? [NSMetadataItem] else { return [] }
        query.stop()
        return results.compactMap { $0.value(forAttribute: NSMetadataItemPathKey) as? String }
    }
}
