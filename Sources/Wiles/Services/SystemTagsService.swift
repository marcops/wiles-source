import AppKit
import Foundation

/// Bridges Wiles' tag UI to the user's actual Finder tag list instead of a hardcoded set.
/// Finder publishes its favorite tags as `FavoriteTagNames` in `com.apple.finder`: an 8-slot
/// array whose index 0 is the empty "no color" slot and indices 1...7 are, in order, the
/// standard colors red, orange, yellow, green, blue, purple, gray — the same order as
/// `TagColor.allCases`. Entries can be renamed or be fully custom, so the name is taken from the
/// array and the color from the slot position.
@MainActor
public enum SystemTagsService {
    private static let finderDomain = "com.apple.finder"
    private static let favoriteTagsKey = "FavoriteTagNames"

    /// Cached Finder favorite-tag list. Populated by `startObserving()` at app launch and refreshed
    /// when any app is activated (Finder edits its tag list while frontmost; switching back to Wiles
    /// then picks the change up). It is NEVER read from disk inside a SwiftUI `body` — the old
    /// getter did a cross-app `UserDefaults` parse per tag per row every time its 5s TTL lapsed,
    /// i.e. `DEV_RULES.md` #19 (finding ML-070). `nil` until the first refresh; readers fall back
    /// to the seven standard colors until then.
    private static var cachedFavoriteTags: [SystemTag]?
    private static var activationObserver: (any NSObjectProtocol)?

    private static var standardFallback: [SystemTag] {
        TagColor.allCases.map { SystemTag(name: $0.rawValue.capitalized, color: $0) }
    }

    /// The user's Finder favorite tags in Finder's own order, from the cache only. Falls back to the
    /// seven standard colors (English names) until `startObserving()`/`refresh()` has run or when
    /// Finder's prefs aren't readable.
    public static var favoriteTags: [SystemTag] {
        cachedFavoriteTags ?? standardFallback
    }

    /// Seeds the cache and keeps it current off the render path. Call once from app launch;
    /// idempotent.
    public static func startObserving() {
        guard activationObserver == nil else { return }
        refresh()
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { refresh() }
            }
    }

    /// Re-reads Finder's favorite tags into the cache. This is the one place the cross-app
    /// `UserDefaults` read happens, and it's only ever called from `startObserving`'s observer or
    /// an explicit `invalidateCache()` — never from a view body.
    public static func refresh() {
        cachedFavoriteTags = readFavoriteTagsFromFinderPrefs()
    }

    /// Forces an immediate re-parse of Finder's prefs.
    public static func invalidateCache() {
        refresh()
    }

    private static func readFavoriteTagsFromFinderPrefs() -> [SystemTag] {
        guard let raw = UserDefaults(suiteName: finderDomain)?.stringArray(forKey: favoriteTagsKey) else {
            return standardFallback
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
