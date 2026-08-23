import Foundation

enum RenameTabMode: String, CaseIterable, Identifiable {
    case findReplace = "Find & Replace"
    case prefixSuffix = "Prefix & Suffix"
    case sequence = "Sequence"
    case regex = "Regex"

    var id: String {
        rawValue
    }
}
