import Foundation

public enum NavigationMode: String, CaseIterable, Identifiable, Sendable {
    case gnome = "GNOME Mode (Enter to Open, F2 to Rename)"
    case macOS = "macOS Mode (Cmd+Down to Open, Enter to Rename)"

    public var id: String { rawValue }

    public var shortName: String {
        switch self {
        case .gnome: return "GNOME Mode"
        case .macOS: return "macOS Mode"
        }
    }
}
