import SwiftUI

public struct FileItemIconView: View {
    let item: FileItem
    let size: CGFloat

    public init(item: FileItem, size: CGFloat) {
        self.item = item
        self.size = size
    }

    public var body: some View {
        if !item.isDirectory {
            ImageThumbnailView(url: item.url, size: size, fallback: item.icon)
                .frame(width: size, height: size)
        } else {
            Image(nsImage: item.icon)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        }
    }
}
