import AppKit
import SwiftUI

struct CursorModifier: ViewModifier {
    let cursor: NSCursor
    /// Tracks whether this modifier currently owns a pushed cursor, so a repeated hover-enter (which
    /// SwiftUI does fire) can't stack two pushes against one pop, and `onDisappear` can unwind a
    /// push left dangling when the view is removed while still hovered.
    @State private var didPush = false

    func body(content: Content) -> some View {
        content
            .onHover { inside in
                if inside, !didPush {
                    cursor.push()
                    didPush = true
                } else if !inside, didPush {
                    NSCursor.pop()
                    didPush = false
                }
            }
            .onDisappear {
                if didPush {
                    NSCursor.pop()
                    didPush = false
                }
            }
    }
}
