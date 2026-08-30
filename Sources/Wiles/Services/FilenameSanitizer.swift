import Foundation

/// Turns a user-typed rename into a valid POSIX filename the way Finder does, instead of letting
/// a stray `/` or control character reach `FileManager` and surface as a raw system error.
enum FilenameSanitizer {
    /// - A typed `/` becomes `:` — Finder shows an on-disk `:` as `/` in the UI and swaps it back
    ///   on save, since `/` is the POSIX path separator and can't appear in a filename.
    /// - Control characters (NUL, tab, newline, DEL, …) are dropped.
    /// - Surrounding whitespace is trimmed.
    /// Returns `nil` when nothing usable is left (empty, all-whitespace, `.` or `..`).
    static func sanitize(_ raw: String) -> String? {
        let slashSwapped = raw.replacingOccurrences(of: "/", with: ":")
        let withoutControls = slashSwapped.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }
        let cleaned = String(String.UnicodeScalarView(withoutControls)).trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty, cleaned != ".", cleaned != ".." else { return nil }
        return cleaned
    }
}
