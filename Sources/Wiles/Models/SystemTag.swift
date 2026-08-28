/// One of the user's Finder tags: the real on-disk name plus, when it occupies one of Finder's
/// seven standard color slots, the matching `TagColor` for its dot.
public struct SystemTag: Sendable, Hashable {
    public let name: String
    public let color: TagColor?
}
