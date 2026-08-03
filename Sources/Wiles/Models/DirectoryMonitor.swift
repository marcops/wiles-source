import Foundation
import Dispatch

final class DirectoryMonitor: Sendable {
    nonisolated(unsafe) private var source: DispatchSourceFileSystemObject?
    nonisolated(unsafe) private var fd: Int32 = -1
    
    func start(path: String, onChange: @escaping @Sendable () -> Void) {
        cancel()
        fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }
        let s = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename], queue: .global())
        s.setEventHandler(handler: onChange)
        s.setCancelHandler { [fd] in close(fd) }
        s.resume()
        source = s
    }
    
    func cancel() {
        source?.cancel()
        source = nil
    }
    
    deinit {
        cancel()
    }
}
