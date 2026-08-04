import Foundation
import AppKit

@MainActor
public protocol ThumbnailServiceProtocol {
    func loadThumbnail(for url: URL, size: CGFloat) async -> NSImage?
    func cachedThumbnail(for url: URL, size: CGFloat) -> NSImage?
    func prefetchThumbnails(for items: [FileItem], size: CGFloat)
}
