import Foundation

public enum UndoActionType: Sendable {
    case rename(oldURL: URL, newURL: URL)
    case move(sourceURL: URL, destinationURL: URL)
    case createFolder(url: URL)
    case createFile(url: URL)
    case trash(originalURL: URL, trashedURL: URL)
}
