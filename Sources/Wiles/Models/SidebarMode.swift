import Foundation

public enum SidebarMode: String, CaseIterable, Identifiable, Sendable {
    case places = "Places"
    case tree = "Tree"
    
    public var id: String { rawValue }
}
