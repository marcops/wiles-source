import SwiftUI
import AppKit

/// Invisible drag handle placed at the trailing edge of each resizable column header.
/// Shows a visible divider on hover and changes the cursor to a resize cursor.
struct ColumnResizeHandle: View {
    let column: ListColumn
    var appState: AppState

    @State private var isHovered = false
    @State private var dragStartX: CGFloat? = nil
    @State private var dragStartWidth: CGFloat? = nil

    private static let handleWidth: CGFloat = 8

    var body: some View {
        Rectangle()
            .fill(isHovered ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.15))
            .frame(width: Self.handleWidth)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if dragStartX == nil {
                            dragStartX = value.startLocation.x
                            dragStartWidth = appState.columnWidth(for: column)
                        }
                        let delta = value.location.x - (dragStartX ?? 0)
                        let base = dragStartWidth ?? column.defaultWidth
                        appState.setColumnWidth(column, width: base + delta)
                    }
                    .onEnded { _ in
                        dragStartX = nil
                        dragStartWidth = nil
                        NSCursor.pop()
                    }
            )
            .cursor(.resizeLeftRight)
    }
}

// MARK: - Cursor modifier helper

private struct CursorModifier: ViewModifier {
    let cursor: NSCursor
    func body(content: Content) -> some View {
        content.onHover { inside in
            if inside { cursor.push() } else { NSCursor.pop() }
        }
    }
}

private extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        modifier(CursorModifier(cursor: cursor))
    }
}
