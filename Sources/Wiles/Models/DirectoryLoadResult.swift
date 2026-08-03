import Foundation

public struct DirectoryLoadResult: Sendable {
    public let items: [FileItem]
    public let isPermissionDenied: Bool
    
    public init(items: [FileItem], isPermissionDenied: Bool = false) {
        self.items = items
        self.isPermissionDenied = isPermissionDenied
    }
}
