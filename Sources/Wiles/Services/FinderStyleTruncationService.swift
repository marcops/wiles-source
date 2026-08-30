import AppKit

/// Replicates Finder's filename truncation: keeps an equal number of characters from the start
/// and end, dropping the middle behind a single "…" — and pre-splits the result into real lines
/// (joined by "\n"), since `Text` doesn't reliably wrap an unbroken filename on its own.
public enum FinderStyleTruncationService {
    /// Slack so a line landing right at the boundary doesn't get double-truncated by `Text`'s own
    /// `.lineLimit` when it measures a hair wider than TextKit did.
    private static let measurementSafetyMargin: CGFloat = 2.0

    /// `truncatedMiddle` is read from SwiftUI `body` for every visible cell on every render, and its
    /// inputs (name, font, rounded width, line cap) repeat heavily across renders of one folder.
    /// `NSCache` is internally synchronized, so this is safe to touch from any actor without a lock.
    private nonisolated(unsafe) static let truncationCache: NSCache<NSString, NSString> = {
        let cache = NSCache<NSString, NSString>()
        cache.countLimit = 4000
        return cache
    }()

    /// Same rationale as `truncationCache`, for `wrappedLines` — `revealFieldOverlay` calls it from
    /// `body`, re-hit on every scroll frame while a name is revealed.
    private nonisolated(unsafe) static let wrappedLinesCache: NSCache<NSString, NSArray> = {
        let cache = NSCache<NSString, NSArray>()
        cache.countLimit = 1000
        return cache
    }()

    /// One reusable TextKit graph instead of a fresh `NSLayoutManager`/`NSTextStorage`/`NSTextContainer`
    /// per `fits()` step of the binary search. `layoutLock` serializes access since `precompute` runs
    /// off-main while a stray `body` cache-miss can still land on the main thread.
    private static let layoutLock = NSLock()
    private nonisolated(unsafe) static let layoutEngine = TruncationLayoutEngine()

    public static func truncatedMiddle(_ name: String, font: NSFont, maxWidth: CGFloat, maxLines: Int) -> String {
        let clampedWidth = maxWidth - measurementSafetyMargin
        guard clampedWidth > 0, maxLines > 0, !name.isEmpty else { return name }

        let cacheKey = "\(font.fontName)|\(font.pointSize)|\(Int(clampedWidth.rounded()))|\(maxLines)|\(name)" as NSString
        if let cached = truncationCache.object(forKey: cacheKey) {
            return cached as String
        }

        layoutLock.lock()
        defer { layoutLock.unlock() }

        let content = fitsLocked(name, font: font, maxWidth: clampedWidth, maxLines: maxLines)
            ? name
            : middleTruncatedCandidate(for: name, font: font, maxWidth: clampedWidth, maxLines: maxLines)

        let result: String
        if maxLines > 1 {
            let lines = wrappedLinesLocked(content, font: font, maxWidth: clampedWidth, maxLines: maxLines)
            result = lines.isEmpty ? content : lines.joined(separator: "\n")
        } else {
            result = content
        }

        truncationCache.setObject(result as NSString, forKey: cacheKey)
        return result
    }

    /// Run off-main when a directory loads (like the thumbnail prefetch) so every later `truncatedMiddle`
    /// read from a cell `body` is a pure cache hit. Not yet wired to a caller — callers must invoke this
    /// with the same `font`/`width`/`maxLines` the cells will use.
    public static func precompute(_ items: [FileItem], width: CGFloat, font: NSFont, maxLines: Int = 2) {
        for item in items {
            _ = truncatedMiddle(item.name, font: font, maxWidth: width, maxLines: maxLines)
        }
    }

    /// Wraps `text` into as many lines as it needs, no truncation, no line cap — for showing the
    /// full name after it's been revealed.
    public static func wrappedLines(_ text: String, font: NSFont, maxWidth: CGFloat) -> [String] {
        let maxWidth = maxWidth - measurementSafetyMargin
        guard maxWidth > 0, !text.isEmpty else { return [text] }
        let cacheKey = "\(font.fontName)|\(font.pointSize)|\(Int(maxWidth.rounded()))|\(text)" as NSString
        if let cached = wrappedLinesCache.object(forKey: cacheKey) as? [String] {
            return cached
        }
        layoutLock.lock()
        // `NSTextContainer.maximumNumberOfLines = 0` is AppKit's own "no limit" sentinel.
        let result = wrappedLinesLocked(text, font: font, maxWidth: maxWidth, maxLines: 0)
        layoutLock.unlock()
        wrappedLinesCache.setObject(result as NSArray, forKey: cacheKey)
        return result
    }

    /// Binary-searches the largest equal prefix/suffix ("…"-joined) that still fits. Caller holds `layoutLock`.
    private static func middleTruncatedCandidate(for name: String, font: NSFont, maxWidth: CGFloat, maxLines: Int) -> String {
        let chars = Array(name)
        var low = 1
        var high = chars.count / 2
        var best = "…"
        while low <= high {
            let mid = (low + high) / 2
            let candidate = String(chars.prefix(mid)) + "…" + String(chars.suffix(mid))
            if fitsLocked(candidate, font: font, maxWidth: maxWidth, maxLines: maxLines) {
                best = candidate
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return best
    }

    /// Real `NSLayoutManager` layout instead of a font-metrics formula, which drifted from actual wrapping.
    /// Caller holds `layoutLock`.
    private static func fitsLocked(_ text: String, font: NSFont, maxWidth: CGFloat, maxLines: Int) -> Bool {
        let layoutManager = layoutEngine.layout(text, font: font, maxWidth: maxWidth, maxLines: maxLines)
        let fittedGlyphCount = layoutManager.glyphRange(for: layoutManager.textContainers[0]).length
        return fittedGlyphCount >= layoutManager.numberOfGlyphs
    }

    /// Reads back each real line fragment TextKit laid out, including its own mid-word breaks.
    /// Caller holds `layoutLock`.
    private static func wrappedLinesLocked(_ text: String, font: NSFont, maxWidth: CGFloat, maxLines: Int) -> [String] {
        let layoutManager = layoutEngine.layout(text, font: font, maxWidth: maxWidth, maxLines: maxLines)
        let nsText = text as NSString
        var lines: [String] = []
        var glyphIndex = 0
        let totalGlyphs = layoutManager.numberOfGlyphs
        while glyphIndex < totalGlyphs, maxLines <= 0 || lines.count < maxLines {
            var lineGlyphRange = NSRange(location: 0, length: 0)
            layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineGlyphRange)
            let lineCharRange = layoutManager.characterRange(forGlyphRange: lineGlyphRange, actualGlyphRange: nil)
            lines.append(nsText.substring(with: lineCharRange))
            glyphIndex = NSMaxRange(lineGlyphRange)
        }
        return lines
    }

    /// Reusable TextKit graph; `layout` resets it in place. Not thread-safe on its own — access is
    /// serialized by `FinderStyleTruncationService.layoutLock`.
    private final class TruncationLayoutEngine {
        private let textStorage = NSTextStorage()
        private let layoutManager = NSLayoutManager()
        private let container = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))

        init() {
            container.lineFragmentPadding = 0
            layoutManager.addTextContainer(container)
            textStorage.addLayoutManager(layoutManager)
        }

        func layout(_ text: String, font: NSFont, maxWidth: CGFloat, maxLines: Int) -> NSLayoutManager {
            textStorage.setAttributedString(NSAttributedString(string: text, attributes: [.font: font]))
            container.size = CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude)
            container.maximumNumberOfLines = maxLines
            layoutManager.ensureLayout(for: container)
            return layoutManager
        }
    }
}
