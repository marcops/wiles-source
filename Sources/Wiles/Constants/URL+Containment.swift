import Foundation

extension URL {
    /// True when `self` is `ancestor`, or lives somewhere beneath it. Compared component by
    /// component (both sides `standardizedFileURL` first), so `/Users/foo` is never mistaken for
    /// being inside `/Users/foo2` the way a raw `path.hasPrefix` would.
    ///
    /// `caseInsensitive` (default `true`) matches the APFS-default volume behaviour, where the two
    /// URLs can legitimately spell a shared ancestor with different casing.
    ///
    /// The one shared home for what was copy-pasted across `AppState+Navigation.childToRestore`,
    /// `FolderPickerSheet.isWithinOrEqual`, and `FolderNode.loadSubfolders`.
    func isDescendantOrSelf(of ancestor: URL, caseInsensitive: Bool = true) -> Bool {
        let mine = standardizedFileURL.pathComponents
        let theirs = ancestor.standardizedFileURL.pathComponents
        guard mine.count >= theirs.count else { return false }
        return zip(mine, theirs).allSatisfy { lhs, rhs in
            caseInsensitive ? lhs.caseInsensitiveCompare(rhs) == .orderedSame : lhs == rhs
        }
    }
}
