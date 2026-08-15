import Foundation

public enum WilesError: LocalizedError, Equatable, Sendable {
    case permissionDenied(path: String)
    case diskFull(path: String)
    case fileInUse(path: String)
    case itemNotFound(path: String)
    case operationFailed(reason: String)
    case invalidZipPassword
    /// Thrown by moveItem(at:toFolder:) instead of performing any filesystem change when the
    /// destination resolves to the exact same path as the source (moving something to the folder
    /// it's already in). See FileSystemService+Actions.swift's moveItem for why this guard exists —
    /// silently no-op'ing would still leave the user without feedback, and proceeding is what used
    /// to destroy the item (see the regression test in FileSystemTests.swift).
    case itemAlreadyInDestination

    public var errorDescription: String? {
        switch self {
        case let .permissionDenied(path):
            "Permission Denied: Wiles cannot access '\(path)'."
        case let .diskFull(path):
            "Disk Full: Not enough space to complete operation at '\(path)'."
        case let .fileInUse(path):
            "File in Use: '\(path)' is currently open by another application."
        case let .itemNotFound(path):
            "Item Not Found: '\(path)' does not exist."
        case let .operationFailed(reason):
            "Operation Failed: \(reason)"
        case .invalidZipPassword:
            "Invalid Password: Unable to decrypt ZIP archive."
        case .itemAlreadyInDestination:
            "This item is already in that location."
        }
    }
}
