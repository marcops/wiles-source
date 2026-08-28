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

    public static func truncatedMiddle(_ name: String, font: NSFont, maxWidth: CGFloat, maxLines: Int) -> String {
        let clampedWidth = maxWidth - measurementSafetyMargin
        guard clampedWidth > 0, maxLines > 0, !name.isEmpty else { return name }

        let cacheKey = "\(font.fontName)|\(font.pointSize)|\(Int(clampedWidth.rounded()))|\(maxLines)|\(name)" as NSString
        if let cached = truncationCache.object(forKey: cacheKey) {
            return cached as String
        }

        let content = fits(name, font: font, maxWidth: clampedWidth, maxLines: maxLines)
            ? name
            : middleTruncatedCandidate(for: name, font: font, maxWidth: clampedWidth, maxLines: maxLines)

        let result: String
        if maxLines > 1 {
            let lines = wrappedLines(content, font: font, maxWidth: clampedWidth, maxLines: maxLines)
            result = lines.isEmpty ? content : lines.joined(separator: "\n")
        } else {
            result = content
        }

        truncationCache.setObject(result as NSString, forKey: cacheKey)
        return result
    }

    /// Wraps `text` into as many lines as it needs, no truncation, no line cap — for showing the
    /// full name after it's been revealed.
    public static func wrappedLines(_ text: String, font: NSFont, maxWidth: CGFloat) -> [String] {
        let maxWidth = maxWidth - measurementSafetyMargin
        guard maxWidth > 0, !text.isEmpty else { return [text] }
        // `NSTextContainer.maximumNumberOfLines = 0` is AppKit's own "no limit" sentinel.
        return wrappedLines(text, font: font, maxWidth: maxWidth, maxLines: 0)
    }

    /// Binary-searches the largest equal prefix/suffix ("…"-joined) that still fits.
    private static func middleTruncatedCandidate(for name: String, font: NSFont, maxWidth: CGFloat, maxLines: Int) -> String {
        let chars = Array(name)
        var low = 1
        var high = chars.count / 2
        var best = "…"
        while low <= high {
            let mid = (low + high) / 2
            let candidate = String(chars.prefix(mid)) + "…" + String(chars.suffix(mid))
            if fits(candidate, font: font, maxWidth: maxWidth, maxLines: maxLines) {
                best = candidate
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return best
    }

    /// Real `NSLayoutManager` layout instead of a font-metrics formula, which drifted from actual wrapping.
    private static func fits(_ text: String, font: NSFont, maxWidth: CGFloat, maxLines: Int) -> Bool {
        let (layoutManager, textStorage) = makeLayoutManager(for: text, font: font, maxWidth: maxWidth, maxLines: maxLines)
        return withExtendedLifetime(textStorage) {
            let fittedGlyphCount = layoutManager.glyphRange(for: layoutManager.textContainers[0]).length
            return fittedGlyphCount >= layoutManager.numberOfGlyphs
        }
    }

    /// Reads back each real line fragment TextKit laid out, including its own mid-word breaks.
    private static func wrappedLines(_ text: String, font: NSFont, maxWidth: CGFloat, maxLines: Int) -> [String] {
        let (layoutManager, textStorage) = makeLayoutManager(for: text, font: font, maxWidth: maxWidth, maxLines: maxLines)
        return withExtendedLifetime(textStorage) {
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
    }

    /// `NSLayoutManager` doesn't retain its `NSTextStorage` — caller must keep it alive.
    private static func makeLayoutManager(
        for text: String, font: NSFont, maxWidth: CGFloat, maxLines: Int) -> (NSLayoutManager, NSTextStorage) {
        let textStorage = NSTextStorage(string: text, attributes: [.font: font])
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let container = NSTextContainer(size: CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        container.maximumNumberOfLines = maxLines
        container.lineBreakMode = .byWordWrapping
        layoutManager.addTextContainer(container)
        layoutManager.ensureLayout(for: container)
        return (layoutManager, textStorage)
    }
}
