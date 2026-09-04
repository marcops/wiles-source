import AppKit

extension NSImage {
    /// New image rasterized to `size` (never mutates the receiver — icons are shared system objects).
    /// One `NSBitmapImageRep` at the target size, unlike `copy().size =` which keeps every full-res rep.
    func resizedCopy(to size: NSSize) -> NSImage {
        let pixelsWide = Int(size.width.rounded())
        let pixelsHigh = Int(size.height.rounded())
        guard pixelsWide > 0, pixelsHigh > 0,
              let bitmap = NSBitmapImageRep(
                  bitmapDataPlanes: nil,
                  pixelsWide: pixelsWide,
                  pixelsHigh: pixelsHigh,
                  bitsPerSample: 8,
                  samplesPerPixel: 4,
                  hasAlpha: true,
                  isPlanar: false,
                  colorSpaceName: .deviceRGB,
                  bytesPerRow: 0,
                  bitsPerPixel: 0)
        else {
            // Degenerate size — fall back to a logical resize of a copy so we still never touch self.
            let copy = (copy() as? NSImage) ?? NSImage(size: size)
            copy.size = size
            return copy
        }
        bitmap.size = size

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSGraphicsContext.current?.imageInterpolation = .high
        draw(
            in: NSRect(origin: .zero, size: size),
            from: .zero,
            operation: .copy,
            fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()

        let result = NSImage(size: size)
        result.addRepresentation(bitmap)
        return result
    }
}
