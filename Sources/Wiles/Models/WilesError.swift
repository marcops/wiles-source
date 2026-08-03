import Foundation

public enum WilesError: LocalizedError, Equatable, Sendable {
    case permissionDenied(path: String)
    case diskFull(path: String)
    case fileInUse(path: String)
    case itemNotFound(path: String)
    case operationFailed(reason: String)
    case invalidZipPassword

    public var errorDescription: String? {
        switch self {
        case .permissionDenied(let path):
            return "Permission Denied: Wiles cannot access '\(path)'."
        case .diskFull(let path):
            return "Disk Full: Not enough space to complete operation at '\(path)'."
        case .fileInUse(let path):
            return "File in Use: '\(path)' is currently open by another application."
        case .itemNotFound(let path):
            return "Item Not Found: '\(path)' does not exist."
        case .operationFailed(let reason):
            return "Operation Failed: \(reason)"
        case .invalidZipPassword:
            return "Invalid Password: Unable to decrypt ZIP archive."
        }
    }
}
