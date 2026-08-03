import SwiftUI
import AppKit

/// Interactive drag handle placed at the trailing edge of a table column.
/// Dragging left/right adjusts the column width directly, matching macOS Finder behavior.
struct ColumnResizeHandle: View {
    let column: ListColumn
    var appState: AppState

    @State private var isHovered = false
    @State private var dragStartWidth: CGFloat? = nil

    private static let hitAreaWidth: CGFloat = 8
    private static let lineWidth: CGFloat = 1

    var body: some View {
        ZStack {
            // Wide transparent hit area
            Color.clear
                .frame(width: Self.hitAreaWidth)
                .contentShape(Rectangle())

            // 1pt visual divider line
            Rectangle()
                .fill(isHovered ? Color.accentColor : Color.secondary.opacity(0.25))
                .frame(width: Self.lineWidth)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { isHovered = hovering }
            if hovering { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
        }
        .onTapGesture(count: 2) {
            appState.autoFitColumnWidth(column)
        }
        .gesture(
            DragGesture(coordinateSpace: .global)
                .onChanged { value in
                    if dragStartWidth == nil {
                        dragStartWidth = appState.columnWidth(for: column)
                    }
                    let dx = value.translation.width
                    let initWidth = dragStartWidth ?? column.defaultWidth
                    let newWidth = max(LayoutTokens.columnMinWidth, initWidth + dx)
                    
                    appState.setColumnWidth(column, width: newWidth)
                }
                .onEnded { _ in
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
