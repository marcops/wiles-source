import Foundation

public enum UndoActionType: Sendable {
    case rename(oldURL: URL, newURL: URL)
    case move(sourceURL: URL, destinationURL: URL)
    case create(url: URL)
    case trash(originalURL: URL, trashedURL: URL)
}
