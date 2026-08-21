import CoreServices
import Foundation

final class DirectoryMonitor: @unchecked Sendable {
    private var streamRef: FSEventStreamRef?
    private var callback: (@Sendable () -> Void)?
    /// Synchronizes `streamRef`/`callback` between start()/cancel() (called from @MainActor) and
    /// the FSEvents callback trampoline (invoked on DispatchQueue.global(qos: .utility)).
    private let stateQueue = DispatchQueue(label: "com.wiles.DirectoryMonitor.state")

    func start(path: String, onChange: @escaping @Sendable () -> Void) {
        cancel()
        stateQueue.sync { callback = onChange }

        let pathsToWatch = [path as NSString] as CFArray
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil)

        let callbackImpl: FSEventStreamCallback = { _, clientCallBackInfo, _, _, _, _ in
            guard let clientCallBackInfo else { return }
            let monitor = Unmanaged<DirectoryMonitor>.fromOpaque(clientCallBackInfo).takeUnretainedValue()
            let onChange = monitor.stateQueue.sync { monitor.callback }
            onChange?()
        }

        let flags = UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callbackImpl,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.1,
            flags) else { return }

        stateQueue.sync { streamRef = stream }
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.global(qos: .utility))
        FSEventStreamStart(stream)
    }

    func cancel() {
        guard let stream = stateQueue.sync(execute: { streamRef }) else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        stateQueue.sync {
            streamRef = nil
            callback = nil
        }
    }

    deinit {
        cancel()
    }
}
