import AppKit

/// Replicates Finder's filename truncation: when a name doesn't fit within `maxLines` at
/// `maxWidth`, it keeps an equal number of characters from the start and end and drops the middle,
/// joined by a single ellipsis — instead of the default end-only ("Very Long File Na…") truncation.
public enum FinderStyleTruncationService {
    public static func truncatedMiddle(_ name: String, font: NSFont, maxWidth: CGFloat, maxLines: Int) -> String {
        guard maxWidth > 0, maxLines > 0, !name.isEmpty else { return name }
        guard wrappedLineCount(name, font: font, maxWidth: maxWidth) > maxLines else { return name }

        let chars = Array(name)
        var low = 1
        var high = chars.count / 2
        var best = "…"
        while low <= high {
            let mid = (low + high) / 2
            let candidate = String(chars.prefix(mid)) + "…" + String(chars.suffix(mid))
            if wrappedLineCount(candidate, font: font, maxWidth: maxWidth) <= maxLines {
                best = candidate
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return best
    }

    private static func wrappedLineCount(_ text: String, font: NSFont, maxWidth: CGFloat) -> Int {
        let attributed = NSAttributedString(string: text, attributes: [.font: font])
        let bounding = attributed.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading])
        let lineHeight = lineHeight(for: font)
        guard lineHeight > 0 else { return 1 }
        // Subtract a small epsilon before dividing so floating-point imprecision on a height that
        // exactly equals N whole lines doesn't get rounded up into N+1.
        let lines = max(0, bounding.height - 0.5) / lineHeight
        return max(1, Int(lines.rounded(.up)))
    }

    private static func lineHeight(for font: NSFont) -> CGFloat {
        font.ascender - font.descender + font.leading
    }
}
