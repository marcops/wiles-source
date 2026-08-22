import AppKit
import Foundation
import GitBeacon

public final class PasteboardService: Sendable {
    public static func writeToPasteboard(urls: [URL]) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects(urls as [NSURL])
    }

    public static func readFromPasteboard() -> [URL]? {
        let pb = NSPasteboard.general
        return pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL]
    }

    /// Pasting with nothing "file-shaped" on the pasteboard (no dragged/copied files) still does
    /// something useful, matching Finder's "New Item from Clipboard": a copied screenshot or image
    /// becomes a new `.png`, and copied text becomes a new `.txt`, right in the current folder.
    /// Checked in that order since some image sources also expose a redundant string
    /// representation on the same pasteboard. Returns `nil` only when there's genuinely nothing
    /// pasteable; a disk write failure once content was found instead throws, so the caller can
    /// surface it instead of it disappearing silently.
    @discardableResult
    public static func createFileFromPasteboardContent(in folder: URL) throws -> URL? {
        let pb = NSPasteboard.general
        if let image = pb.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage,
           let pngData = pngData(for: image) {
            let destURL = FileSystemService.uniqueDestination(for: "Pasted Image.png", in: folder)
            try pngData.write(to: destURL)
            return destURL
        }
        if let text = pb.string(forType: .string), !text.isEmpty {
            let destURL = FileSystemService.uniqueDestination(for: "Pasted Text.txt", in: folder)
            try text.write(to: destURL, atomically: true, encoding: .utf8)
            return destURL
        }
        return nil
    }

    private static func pngData(for image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }

    public static func copyFileContentToClipboard(url: URL) {
        // Reading the file (up to 10MB) can stall for seconds on a slow or stalled
        // network/SMB mount. Perform the read off the main actor and round-trip only the
        // resulting string back, mirroring the /Volumes slow-mount pattern used by
        // AppState+Navigation.swift's navigateTo. The signature stays synchronous so callers
        // don't need to change; the heavy work is dispatched internally instead.
        Task.detached(priority: .userInitiated) {
            do {
                let values = try url.resourceValues(forKeys: [.fileSizeKey])
                guard let size = values.fileSize, size < 10_000_000 else { return }
                let content = try String(contentsOf: url)
                await copyToClipboard(content)
            } catch {
                ErrorReporter.report(error, context: "Copying file content to clipboard for \(url.path)")
            }
        }
    }

    private static func copyToClipboard(_ content: String) async {
        await MainActor.run {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(content, forType: .string)
        }
    }
}
