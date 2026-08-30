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
    /// Thrown when a move/symlink/create would land on a name that already exists at the
    /// destination, instead of overwriting or deleting what's there. The caller decides what to do
    /// (prompt the user, auto-rename); if it reaches an alert unhandled, the message names the item.
    case destinationExists(name: String)
    /// Thrown by `UndoRedoService.executeForwardAction(_:)`'s `.createFile` case: redoing an undone
    /// file creation would require recreating the original file's exact content, which `.createFile`
    /// never stored (unlike `.createFolder`, whose redo can always just call `createDirectory` again
    /// since an empty folder has no content to lose). Throwing here instead of silently creating a
    /// folder in the file's place is the whole point of splitting `.create` into `.createFolder`/
    /// `.createFile` — see `UndoActionType.swift`.
    case fileCreationNotRedoable
    /// A user-facing failure from a stateless service (`ArchiveService`, `ImageConverterService`, …)
    /// that has no access to the in-app language. Carrying the `L10n.Key` (+ any `%@` args) instead
    /// of a pre-rendered string lets `AppState.showError` localize it at display time in the app's
    /// chosen language, not the system one. See lint rule LR2.
    case localized(key: L10n.Key, arguments: [String])

    /// `LocalizedError` conformance — the system-language rendering of the same message
    /// `localizedMessage(lang:)` builds from `l10nKey` + token substitution. Kept as a thin
    /// delegate so there's exactly one source of truth per error (no hand-written English copy to
    /// drift from `en.lproj`).
    public var errorDescription: String? {
        localizedMessage(lang: .system)
    }

    /// The one token-substitution mechanism for every case. A translation missing a token just
    /// no-ops (unlike `String(format:)`, which can misread the varargs stack on bad translation data).
    private static func substitute(_ template: String, _ tokens: [String: String]) -> String {
        tokens.reduce(template) { $0.replacingOccurrences(of: $1.key, with: $1.value) }
    }

    private static func positionalTokens(_ arguments: [String]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: arguments.enumerated().map { ("{\($0.offset)}", $0.element) })
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
        case .destinationExists: .wilesErrorDestinationExists
        case .fileCreationNotRedoable: .wilesErrorFileCreationNotRedoable
        case let .localized(key, _): key
        }
    }

    /// Localized, user-facing message — substitutes any associated path/reason into the localized
    /// template via `l10nKey`. Prefer this over `errorDescription`/`localizedDescription` wherever
    /// a `WilesError` reaches a visible alert.
    ///
    public func localizedMessage(lang: AppLanguage) -> String {
        let template = L10n.string(l10nKey, lang: lang)
        switch self {
        case let .permissionDenied(path), let .diskFull(path), let .fileInUse(path), let .itemNotFound(path):
            return Self.substitute(template, ["{path}": path])
        case let .operationFailed(reason):
            return Self.substitute(template, ["{reason}": reason])
        case let .destinationExists(name):
            return Self.substitute(template, ["{name}": name])
        case let .localized(_, arguments):
            return Self.substitute(template, Self.positionalTokens(arguments))
        case .invalidZipPassword, .itemAlreadyInDestination, .fileCreationNotRedoable:
            return template
        }
    }
}
