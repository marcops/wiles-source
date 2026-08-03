import Foundation
import Dispatch

final class DirectoryMonitor: Sendable {
    nonisolated(unsafe) private var source: DispatchSourceFileSystemObject?
    nonisolated(unsafe) private var fd: Int32 = -1

    func start(path: String, onChange: @escaping @Sendable () -> Void) {
        cancel()
        fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .attrib, .extend, .link],
            queue: .global()
        )
        src.setEventHandler(handler: onChange)
        src.setCancelHandler { [fd] in close(fd) }
        src.resume()
        source = src
    }

    func cancel() {
        source?.cancel()
        source = nil
    }

    deinit {
        cancel()
    }
}
