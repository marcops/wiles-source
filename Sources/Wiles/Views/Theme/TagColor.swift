import SwiftUI

/// Single source of truth for the app's fixed set of tag colors — the sidebar's tag list
/// and `colorForTag(_:)` both derive from this instead of hardcoding the name list separately.
public enum TagColor: String, CaseIterable {
    case red
    case orange
    case yellow
    case green
    case blue
    case purple
    case gray

    public var displayColor: Color {
        switch self {
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .blue: .blue
        case .purple: .purple
        case .gray: .gray
        }
    }

    public var localizationKey: L10n.Key {
        switch self {
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .blue: .blue
        case .purple: .purple
        case .gray: .gray
        }
    }
}

public func colorForTag(_ tag: String) -> Color {
    let normalized = tag.lowercased() == "grey" ? "gray" : tag.lowercased()
    return TagColor(rawValue: normalized)?.displayColor ?? .secondary
}
