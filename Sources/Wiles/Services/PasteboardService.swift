import AppKit
import Foundation

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

    /// Cap for copying a file's full text to the clipboard (a bigger read would also stall).
    /// Independent of `SearchFilterService`'s content-match cap — different use case, not shared.
    private static let maxCopyableTextBytes = 10_000_000

    /// Copies the file's text content to the clipboard. Throws `WilesError.localized` for the two
    /// user-visible failure cases — file too large, or not decodable as text — so the caller
    /// (`AppState.copyContentOfSelected`) can surface them instead of the copy silently no-op'ing.
    /// The read runs off the main actor: it can stall for seconds on a slow/stalled network mount.
    public static func copyFileContentToClipboard(url: URL) async throws {
        let content = try await readTextForClipboard(at: url)
        await copyToClipboard(content)
    }

    private static func readTextForClipboard(at url: URL) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
            if let size, size >= maxCopyableTextBytes {
                throw WilesError.localized(key: .copyContentFileTooLarge, arguments: [])
            }
            do {
                return try String(contentsOf: url)
            } catch {
                throw WilesError.localized(key: .copyContentNotText, arguments: [])
            }
        }.value
    }

    private static func copyToClipboard(_ content: String) async {
        await MainActor.run {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(content, forType: .string)
        }
    }
}
