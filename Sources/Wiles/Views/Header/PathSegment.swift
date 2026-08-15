import Foundation

struct PathSegment: Identifiable, Hashable {
    var id: String {
        url.path
    }

    let name: String
    let url: URL
    let isFirst: Bool
}
