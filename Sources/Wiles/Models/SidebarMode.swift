import Foundation

public enum SidebarMode: String, CaseIterable, Identifiable, Sendable {
    case places = "Places"
    case tree = "Tree"
    
    public var id: String { rawValue }
    
    public var l10nKey: L10n.Key {
        switch self {
        case .places: return .places
        case .tree: return .directoryTree
        }
    }
}
