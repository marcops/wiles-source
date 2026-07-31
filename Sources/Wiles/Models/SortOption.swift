import Foundation

public enum SortOption: String, CaseIterable, Identifiable, Hashable, Equatable, Sendable {
    case name = "Name"
    case dateModified = "Date Modified"
    case dateCreated = "Date Created"
    case dateAccessed = "Date Last Opened"
    case size = "Size"
    case kind = "Kind"
    case owner = "Owner"
    case group = "Group"
    public var id: String { rawValue }
}
