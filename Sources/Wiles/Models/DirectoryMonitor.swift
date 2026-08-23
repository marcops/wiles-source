import CoreServices
import Foundation

final class DirectoryMonitor: @unchecked Sendable {
    private static let coalescingLatency: CFTimeInterval = 0.1

    private var streamRef: FSEventStreamRef?
    private var callback: (@Sendable () -> Void)?
    /// Guards `streamRef`/`callback` between start()/cancel() and the FSEvents callback trampoline
    /// (invoked on DispatchQueue.global(qos: .utility)).
    private let lock = NSLock()

    /// `nonisolated`, declared at type scope rather than as a local closure inside `start()`: a
    /// closure lexically nested inside a `@MainActor` method inherits that isolation even when its
    /// own type (`FSEventStreamCallback`, a `@convention(c)` pointer) can't actually run there —
    /// invoking it from the FSEvents background queue then trips Swift's runtime "wrong executor"
    /// check and crashes (`dispatch_assert_queue_fail` inside `_swift_task_checkIsolatedSwift`).
    /// Lifting it out of `start()` removes that inherited isolation.
    private static let fsEventsCallback: FSEventStreamCallback = { _, clientCallBackInfo, _, _, _, _ in
        guard let clientCallBackInfo else { return }
        let monitor = Unmanaged<DirectoryMonitor>.fromOpaque(clientCallBackInfo).takeUnretainedValue()
        let onChange = monitor.lock.withLock { monitor.callback }
        onChange?()
    }

    /// `@MainActor`: every caller (`FileSystemStore`) already runs here — this turns that into a
    /// compiler-checked guarantee instead of just an assertion. `cancel()` deliberately stays
    /// `nonisolated` (already thread-safe via `lock`) since the synchronous `deinit` below
    /// calls it and can't await a hop onto `@MainActor`.
    @MainActor
    func start(path: String, onChange: @escaping @Sendable () -> Void) {
        cancel()
        lock.withLock { callback = onChange }

        let pathsToWatch = [path as NSString] as CFArray
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil)

        let flags = UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            Self.fsEventsCallback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            Self.coalescingLatency,
            flags) else { return }

        lock.withLock { streamRef = stream }
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.global(qos: .utility))
        FSEventStreamStart(stream)
    }

    func cancel() {
        let stream = lock.withLock { () -> FSEventStreamRef? in
            let previousStream = streamRef
            streamRef = nil
            callback = nil
            return previousStream
        }
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
    }

    deinit {
        cancel()
    }
}
