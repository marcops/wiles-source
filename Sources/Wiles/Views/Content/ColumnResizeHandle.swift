import SwiftUI
import AppKit

/// Interactive drag handle placed at the trailing edge of a table column.
/// Dragging left/right adjusts the column width directly, matching macOS Finder behavior.
struct ColumnResizeHandle: View {
    let column: ListColumn
    var appState: AppState

    @State private var isHovered = false
    @State private var dragStartWidth: CGFloat?

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
            withAnimation(MotionTokens.quickEase) { isHovered = hovering }
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

                    // Skip persistence on every intermediate delta — encoding + writing to UserDefaults
                    // on each mouse-move would run dozens of times/sec while dragging. The final width
                    // is persisted once in .onEnded below.
                    appState.setColumnWidth(column, width: newWidth, persist: false)
                }
                .onEnded { _ in
                    dragStartWidth = nil
                    appState.persistColumnWidths()
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
