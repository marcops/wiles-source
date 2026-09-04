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
    /// `internal`, not `private`: a CI canary test asserts this still resolves to a real icon
    /// (DEV_RULES.md "Reflection / Private-API Access Into a Dependency Needs a CI Canary") — the
    /// point is that a future SDK dropping the legacy selector breaks the build, not production.
    static let openFolderIcon: NSImage = {
        // `perform(_:with:)` raises an uncatchable ObjC "unrecognized selector" exception
        // (not a graceful nil) if the target doesn't implement it — `responds(to:)` must be checked
        // BEFORE calling it, not just the `as? NSImage` cast on its result, so a future SDK dropping
        // this legacy Icon Services selector degrades to the fallback instead of crashing every
        // folder-drag-hover render.
        let selector = NSSelectorFromString("iconForFileType:")
        guard NSWorkspace.shared.responds(to: selector) else {
            return NSWorkspace.shared.icon(for: .folder)
        }
        let hfsType = NSFileTypeForHFSTypeCode(OSType(kOpenFolderIcon))
        if let icon = NSWorkspace.shared.perform(selector, with: hfsType)?
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
            ImageThumbnailView(url: item.url, size: size, fallback: item.icon, dateModified: item.dateModified)
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
