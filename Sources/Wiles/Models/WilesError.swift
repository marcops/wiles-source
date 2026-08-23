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
    /// Thrown by `UndoRedoService.executeForwardAction(_:)`'s `.createFile` case: redoing an undone
    /// file creation would require recreating the original file's exact content, which `.createFile`
    /// never stored (unlike `.createFolder`, whose redo can always just call `createDirectory` again
    /// since an empty folder has no content to lose). Throwing here instead of silently creating a
    /// folder in the file's place is the whole point of splitting `.create` into `.createFolder`/
    /// `.createFile` — see `UndoActionType.swift`.
    case fileCreationNotRedoable

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
        case .fileCreationNotRedoable:
            "Can't Redo: Wiles doesn't store the original file's content, so this creation can't be redone."
        }
    }

    public var l10nKey: L10n.Key {
        switch self {
        case .permissionDenied: .wilesErrorPermissionDenied
        case .diskFull: .wilesErrorDiskFull
        case .fileInUse: .wilesErrorFileInUse
        case .itemNotFound: .wilesErrorItemNotFound
        case .operationFailed: .wilesErrorOperationFailed
        case .invalidZipPassword: .wilesErrorInvalidZipPassword
        case .itemAlreadyInDestination: .itemAlreadyInDestination
        case .fileCreationNotRedoable: .wilesErrorFileCreationNotRedoable
        }
    }

    /// Localized, user-facing message — substitutes any associated path/reason into the localized
    /// template via `l10nKey`. Prefer this over `errorDescription`/`localizedDescription` wherever
    /// a `WilesError` reaches a visible alert.
    ///
    /// Uses `{path}`/`{reason}` token substitution rather than `String(format:)` with positional
    /// `%@`: if a translator's string is missing the token, substitution just no-ops instead of
    /// `String(format:)` misreading the varargs stack (a real crash risk driven by translation data).
    public func localizedMessage(lang: AppLanguage) -> String {
        let template = L10n.string(l10nKey, lang: lang)
        switch self {
        case let .permissionDenied(path), let .diskFull(path), let .fileInUse(path), let .itemNotFound(path):
            return template.replacingOccurrences(of: "{path}", with: path)
        case let .operationFailed(reason):
            return template.replacingOccurrences(of: "{reason}", with: reason)
        case .invalidZipPassword, .itemAlreadyInDestination, .fileCreationNotRedoable:
            return template
        }
    }
}
