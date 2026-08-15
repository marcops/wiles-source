import Foundation

public enum ViewMode: String, CaseIterable, Identifiable, Hashable, Equatable, Sendable {
    case grid = "Grid"
    case list = "List"
    case column = "Column"

    public var id: String {
        rawValue
    }
}
