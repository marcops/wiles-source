/// One of the user's Finder tags: the real on-disk name plus, when it occupies one of Finder's
/// seven standard color slots, the matching `TagColor` for its dot.
public struct SystemTag: Sendable, Hashable {
    public let name: String
    public let color: TagColor?

    /// Localized generic color name (e.g. "Red") for a standard slot, following Wiles' language
    /// setting — falls back to `name` for a custom/renamed tag. Display-only: matching/toggling a
    /// tag on a file must still use `name`, the real string stored on disk.
    public func displayName(language: AppLanguage) -> String {
        guard let color else { return name }
        return L10n.string(color.l10nKey, lang: language)
    }
}
