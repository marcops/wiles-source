import Foundation

/// Escapes the five HTML-significant characters so a dynamic value (a file name, a folder name)
/// can be interpolated into served markup without becoming markup itself. Used by
/// `LocalHttpServerService`'s directory listing, where entry names are attacker-influenceable.
public enum HTMLEscaping {
    public static func escape(_ value: String) -> String {
        var result = ""
        result.reserveCapacity(value.count)
        for character in value {
            switch character {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            case "\"": result += "&quot;"
            case "'": result += "&#39;"
            default: result.append(character)
            }
        }
        return result
    }
}
