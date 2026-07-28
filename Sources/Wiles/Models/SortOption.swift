import Foundation

public enum SortOption: String, CaseIterable, Identifiable, Hashable, Equatable, Sendable {
    case name = "Name"
    case dateModified = "Date Modified"
    case size = "Size"
    case kind = "Kind"
    public var id: String { rawValue }
}
