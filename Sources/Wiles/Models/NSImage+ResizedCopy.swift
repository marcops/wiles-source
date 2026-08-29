import AppKit

extension NSImage {
    /// Returns a copy of this image sized to `size`, without ever mutating the receiver. Icons
    /// from `.effectiveIcon` / `NSWorkspace.shared.icon(forFile:)` are shared, cached system
    /// objects — resizing one in place corrupts it everywhere else it's used.
    func resizedCopy(to size: NSSize) -> NSImage {
        if let copy = copy() as? NSImage {
            copy.size = size
            return copy
        }
        // `copy()` failed — draw into a fresh image rather than resizing the shared original.
        return NSImage(size: size, flipped: false) { [self] rect in
            draw(in: rect)
            return true
        }
    }
}
