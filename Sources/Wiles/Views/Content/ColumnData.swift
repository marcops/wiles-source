import AppKit
import SwiftUI

struct ColumnData: Identifiable {
    let id = UUID()
    let folderURL: URL
    var items: [FileItem]
    var selectedURL: URL?
    var visibleLimit: Int = LayoutTokens.paginationThreshold
}
