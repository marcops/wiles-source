import Foundation

/// Bridges Wiles' tag UI to the user's actual Finder tag list instead of a hardcoded set.
/// Finder publishes its favorite tags as `FavoriteTagNames` in `com.apple.finder`: an 8-slot
/// array whose index 0 is the empty "no color" slot and indices 1...7 are, in order, the
/// standard colors red, orange, yellow, green, blue, purple, gray — the same order as
/// `TagColor.allCases`. Entries can be renamed or be fully custom, so the name is taken from the
/// array and the color from the slot position.
public enum SystemTagsService {
    private static let finderDomain = "com.apple.finder"
    private static let favoriteTagsKey = "FavoriteTagNames"

    /// The user's Finder favorite tags in Finder's own order. Falls back to the seven standard
    /// colors (English names) when Finder has never been customized or its prefs aren't readable.
    public static var favoriteTags: [SystemTag] {
        guard let raw = UserDefaults(suiteName: finderDomain)?.stringArray(forKey: favoriteTagsKey) else {
            return TagColor.allCases.map { SystemTag(name: $0.rawValue.capitalized, color: $0) }
        }
        return raw.enumerated().compactMap { index, name in
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }
            let colorSlot = index - 1
            let color = TagColor.allCases.indices.contains(colorSlot) ? TagColor.allCases[colorSlot] : nil
            return SystemTag(name: trimmed, color: color)
        }
    }

    /// The `TagColor` Finder assigns to a tag with this name (case-insensitive), if any.
    public static func color(forTagNamed name: String) -> TagColor? {
        let target = name.lowercased()
        return favoriteTags.first { $0.name.lowercased() == target }?.color
    }
}
