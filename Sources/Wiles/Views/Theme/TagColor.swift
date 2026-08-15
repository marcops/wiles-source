import SwiftUI

public func colorForTag(_ tag: String) -> Color {
    switch tag.lowercased() {
    case "red": .red
    case "orange": .orange
    case "yellow": .yellow
    case "green": .green
    case "blue": .blue
    case "purple": .purple
    case "gray", "grey": .gray
    default: .secondary
    }
}
