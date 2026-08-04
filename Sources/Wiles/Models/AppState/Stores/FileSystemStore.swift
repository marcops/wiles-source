import Foundation
import Observation

@Observable
@MainActor
public final class FileSystemStore {
    public var items: [FileItem] = []
    public var isLoading: Bool = false
    private let directoryMonitor = DirectoryMonitor()

    public init() {}

    public func startDirectoryMonitoring(for url: URL, refreshHandler: @escaping @Sendable () -> Void) {
        guard url.isFileURL else { return }
        directoryMonitor.start(path: url.path) {
            Task { @MainActor in
                refreshHandler()
            }
        }
    }
}
