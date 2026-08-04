import Foundation
import CoreServices

final class DirectoryMonitor: @unchecked Sendable {
    private var streamRef: FSEventStreamRef?
    private var callback: (@Sendable () -> Void)?

    func start(path: String, onChange: @escaping @Sendable () -> Void) {
        cancel()
        self.callback = onChange

        let pathsToWatch = [path as NSString] as CFArray
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callbackImpl: FSEventStreamCallback = { (
            streamRef: ConstFSEventStreamRef,
            clientCallBackInfo: UnsafeMutableRawPointer?,
            numEvents: Int,
            eventPaths: UnsafeMutableRawPointer,
            eventFlags: UnsafePointer<FSEventStreamEventFlags>,
            eventIds: UnsafePointer<FSEventStreamEventId>
        ) in
            guard let clientCallBackInfo else { return }
            let monitor = Unmanaged<DirectoryMonitor>.fromOpaque(clientCallBackInfo).takeUnretainedValue()
            monitor.callback?()
        }

        let flags = UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callbackImpl,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.1,
            flags
        ) else { return }

        self.streamRef = stream
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.global(qos: .utility))
        FSEventStreamStart(stream)
    }

    func cancel() {
        guard let stream = streamRef else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        streamRef = nil
        callback = nil
    }

    deinit {
        cancel()
    }
}
