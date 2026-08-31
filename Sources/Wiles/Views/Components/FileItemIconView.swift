import AppKit
import CoreServices
import SwiftUI
import UniformTypeIdentifiers

public struct FileItemIconView: View {
    let item: FileItem
    let size: CGFloat
    var isOpenTargeted: Bool = false

    public init(item: FileItem, size: CGFloat, isOpenTargeted: Bool = false) {
        self.item = item
        self.size = size
        self.isOpenTargeted = isOpenTargeted
    }

    /// The system's classic "open folder" glyph — same icon Finder swaps to while something is
    /// dragged and held over a folder, right before it spring-loads open. There's no modern
    /// UTType-based API for this legacy Icon Services resource, so it's fetched via the old
    /// `-iconForFileType:` through dynamic dispatch (avoids a hard deprecation warning on the
    /// direct call) with a plain folder icon as a defensive fallback.
    private static let openFolderIcon: NSImage = {
        let hfsType = NSFileTypeForHFSTypeCode(OSType(kOpenFolderIcon))
        if let icon = NSWorkspace.shared.perform(NSSelectorFromString("iconForFileType:"), with: hfsType)?
            .takeUnretainedValue() as? NSImage {
            return icon
        }
        return NSWorkspace.shared.icon(for: .folder)
    }()

    public var body: some View {
        iconContent
            // Decorative: the hosting row/card/sidebar entry already carries the file's label.
            .accessibilityHidden(true)
    }

    @ViewBuilder private var iconContent: some View {
        if item.isDirectory, isOpenTargeted {
            Image(nsImage: Self.openFolderIcon)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size, height: size)
        } else if item.supportsThumbnail {
            ImageThumbnailView(url: item.url, size: size, fallback: item.icon)
                .frame(width: size, height: size)
        } else {
            Image(nsImage: item.icon)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size, height: size)
        }
    }
}
