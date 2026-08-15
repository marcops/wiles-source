import AppKit
import SwiftUI

/// Drag-to-select marquee, background deselect, and the shared background context menu — used by List, Grid, and Column.
/// Draws the rect above the rows itself (this view must stay below them in z-order); needs an ancestor `.coordinateSpace(name: coordinateSpaceName)`.
struct SelectionRectangleOverlay: View {
    var appState: AppState
    var coordinateSpaceName: String
    var minWidth: CGFloat?
    var targetFolderURL: URL?
    @Binding var selectionRect: CGRect?
    /// A closure, not a value, so it's only read on drag — never during body — to avoid re-rendering on every frame update.
    var cellFramesProvider: () -> [URL: CGRect]

    @Environment(WindowUIState.self)
    private var windowUIState
    @State private var dragStartPoint: CGPoint?

    var body: some View {
        Color(NSColor.controlBackgroundColor).opacity(0.001)
            .frame(minWidth: minWidth)
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .onTapGesture { deselectAll() }
            .overlay(RightClickDetector { deselectAll() })
            .contextMenu { SharedBackgroundContextMenu(appState: appState, targetFolderURL: targetFolderURL) }
    }

    private func deselectAll() {
        appState.selectedURLs.removeAll()
        windowUIState.renameItem = nil
    }

    /// Visual marquee rectangle for the current `selectionRect`, drawn separately by the caller
    /// above the row content — see the type-level doc comment for why.
    @ViewBuilder
    static func rectangleOverlay(_ rect: CGRect?) -> some View {
        if let rect {
            Rectangle()
                .fill(Color.accentColor.opacity(0.15))
                .overlay(Rectangle().stroke(Color.accentColor, lineWidth: 1.5))
                .frame(width: rect.width, height: rect.height)
                .offset(x: rect.minX, y: rect.minY)
                .allowsHitTesting(false)
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named(coordinateSpaceName))
            .onChanged(handleDragChanged)
            .onEnded { _ in
                selectionRect = nil
                dragStartPoint = nil
            }
    }

    private func handleDragChanged(_ gesture: DragGesture.Value) {
        let start = dragStartPoint ?? gesture.startLocation
        if dragStartPoint == nil {
            dragStartPoint = start
        }

        let rect = normalizedRect(from: start, to: gesture.location)
        selectionRect = rect
        applySelection(matching: rect)
    }

    private func normalizedRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        let minX = min(start.x, end.x)
        let minY = min(start.y, end.y)
        let maxX = max(start.x, end.x)
        let maxY = max(start.y, end.y)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func applySelection(matching rect: CGRect) {
        var matched = Set<URL>()
        for (url, frame) in cellFramesProvider() where frame.intersects(rect) {
            matched.insert(url)
        }
        let resolved: Set<URL> = if NSEvent.modifierFlags.contains(.command) {
            appState.selectedURLs.union(matched)
        } else {
            matched
        }
        // Only write when the resolved set actually differs — every row reads `selectedURLs`
        // to compute `isSel`, so a write here re-renders the entire visible list. Small mouse
        // movements within the same set of rows would otherwise re-trigger that on every tick.
        if resolved != appState.selectedURLs {
            appState.selectedURLs = resolved
        }
    }
}
