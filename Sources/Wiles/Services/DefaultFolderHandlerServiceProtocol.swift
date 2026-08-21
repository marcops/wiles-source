import Foundation

public protocol DefaultFolderHandlerServiceProtocol: Sendable {
    @MainActor
    static func registerAsFolderHandlerOption(completion: @escaping @Sendable (Bool) -> Void)
}
