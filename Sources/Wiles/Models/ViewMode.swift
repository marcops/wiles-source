import Foundation

public enum ViewMode: String, CaseIterable, Identifiable, Hashable, Equatable, Sendable {
    case grid = "Grid"
    case list = "List"
    public var id: String { rawValue }
}
