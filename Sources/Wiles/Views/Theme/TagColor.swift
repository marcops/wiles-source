import SwiftUI

/// The seven standard Finder tag colors, in Finder's slot order. `SystemTagsService` maps each
/// `FavoriteTagNames` slot to one of these; `colorForTag(_:)` falls back to it by color name.
public enum TagColor: String, CaseIterable, Sendable {
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
}

@MainActor
public func colorForTag(_ tag: String) -> Color {
    if let systemColor = SystemTagsService.color(forTagNamed: tag) {
        return systemColor.displayColor
    }
    let normalized = tag.lowercased() == "grey" ? "gray" : tag.lowercased()
    return TagColor(rawValue: normalized)?.displayColor ?? .secondary
}
