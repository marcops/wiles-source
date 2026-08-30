import Foundation

/// Turns a user-typed rename into a valid POSIX filename the way Finder does, instead of letting
/// a stray `/` or control character reach `FileManager` and surface as a raw system error.
enum FilenameSanitizer {
    /// - A typed `/` becomes `:` — Finder shows an on-disk `:` as `/` in the UI and swaps it back
    ///   on save, since `/` is the POSIX path separator and can't appear in a filename.
    /// - Control characters (NUL, tab, newline, DEL, …) are dropped.
    /// - Surrounding whitespace is trimmed.
    /// - Over-long names are truncated to `maxNameLength`, keeping the extension.
    /// Returns `nil` when nothing usable is left (empty, all-whitespace, `.` or `..`).
    static func sanitize(_ raw: String) -> String? {
        let slashSwapped = raw.replacingOccurrences(of: "/", with: ":")
        let withoutControls = slashSwapped.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }
        let cleaned = String(String.UnicodeScalarView(withoutControls)).trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty, cleaned != ".", cleaned != ".." else { return nil }
        return truncatedToMaxLength(cleaned)
    }

    /// APFS caps a single path component at 255 UTF-8 bytes — measured in bytes, not characters, so
    /// a name of multi-byte scalars can be well under 255 `Character`s yet still fail deep inside
    /// `FileManager` with a raw system error. Truncate the stem by whole characters, keep the extension.
    private static let maxNameByteCount = 255

    private static func truncatedToMaxLength(_ name: String) -> String {
        guard name.utf8.count > maxNameByteCount else { return name }
        let ext = (name as NSString).pathExtension
        let dotExt = ext.isEmpty ? "" : "." + ext
        let stemBudget = maxNameByteCount - dotExt.utf8.count
        guard stemBudget > 0 else { return truncatedToByteCount(name, limit: maxNameByteCount) }
        let stem = (name as NSString).deletingPathExtension
        return truncatedToByteCount(stem, limit: stemBudget) + dotExt
    }

    /// Drops whole characters off the end until the UTF-8 byte count fits `limit` — never splits a
    /// grapheme cluster.
    private static func truncatedToByteCount(_ string: String, limit: Int) -> String {
        var result = string
        while result.utf8.count > limit, !result.isEmpty {
            result.removeLast()
        }
        return result
    }
}
