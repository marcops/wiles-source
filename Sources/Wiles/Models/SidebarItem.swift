import Foundation

struct SidebarItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let iconName: String
    let url: URL
}
