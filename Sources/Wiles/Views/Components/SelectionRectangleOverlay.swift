import SwiftUI
import AppKit

/// Transparent hit-testing background for a file list/grid container: drives the drag-to-select
/// marquee (reporting its current rect via `selectionRect` so the caller can draw it *above* the row
/// content — this view must stay *below* the rows in z-order so row gestures still win), plus
/// background tap-to-deselect, right-click-to-deselect, and the shared empty-area context menu.
/// Matches selection against `appState.selection.gridCellFrames`/`listCellFrames` (populated by
/// row-level preference-key frames), read only inside the drag-gesture handler — never from this
/// view's `body` — so the caller (FileGridView/FileListView) never re-renders when a newly-visible
/// lazy row updates the cell-frame dictionary during scrolling.
/// Expects an ancestor `.coordinateSpace(name: coordinateSpaceName)`.
struct SelectionRectangleOverlay: View {
    var appState: AppState
    var coordinateSpaceName: String
    var minWidth: CGFloat?
    @Binding var selectionRect: CGRect?

    @State private var dragStartPoint: CGPoint?

    private var cellFrames: [URL: CGRect] {
        coordinateSpaceName == "gridContainer" ? appState.selection.gridCellFrames : appState.selection.listCellFrames
    }

    var body: some View {
        Color(NSColor.controlBackgroundColor).opacity(0.001)
            .frame(minWidth: minWidth)
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .onTapGesture { appState.selectedURLs.removeAll() }
            .overlay(RightClickDetector { appState.selectedURLs.removeAll() })
            .contextMenu { SharedBackgroundContextMenu(appState: appState) }
    }

    /// Visual marquee rectangle for the current `selectionRect`, drawn separately by the caller
    /// above the row content — see the type-level doc comment for why.
    static func rectangleOverlay(_ rect: CGRect?) -> some View {
        Group {
            if let rect {
                Rectangle()
                    .fill(Color.accentColor.opacity(0.15))
                    .overlay(Rectangle().stroke(Color.accentColor, lineWidth: 1.5))
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY)
                    .allowsHitTesting(false)
            }
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
        if dragStartPoint == nil { dragStartPoint = start }

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
        for (url, frame) in cellFrames where frame.intersects(rect) {
            matched.insert(url)
        }
        let resolved: Set<URL>
        if NSEvent.modifierFlags.contains(.command) {
            resolved = appState.selectedURLs.union(matched)
        } else {
            resolved = matched
        }
        // Only write when the resolved set actually differs — every row reads `selectedURLs`
        // to compute `isSel`, so a write here re-renders the entire visible list. Small mouse
        // movements within the same set of rows would otherwise re-trigger that on every tick.
        if resolved != appState.selectedURLs {
            appState.selectedURLs = resolved
        }
    }
}
