import Foundation

public struct UndoRecord: Sendable {
    public let id = UUID()
    let actionType: UndoActionType
    let timestamp = Date()
}
