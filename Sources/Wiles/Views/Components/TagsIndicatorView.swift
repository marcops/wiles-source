import AppKit
import SwiftUI

/// Small colored circular "tag chip" indicator for a file's Finder tags — shared by the grid card
/// (`FileGridCardItemView`) and list row (`FileListView`) leaf renderers. Callers gate visibility
/// on `appState.preferences.showTags`/`item.tags.isEmpty` themselves, since that check also decides
/// whether to reserve any layout space at all, and apply any mode-specific styling (e.g. the list's
/// compact-mode vertical offset) on top of this view rather than as a parameter here.
public struct TagsIndicatorView: View {
    let tags: [String]

    public init(tags: [String]) {
        self.tags = tags
    }

    public var body: some View {
        HStack(alignment: .center, spacing: -2) {
            ForEach(tags, id: \.self) { tag in
                Circle()
                    .fill(colorForTag(tag))
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(Color(NSColor.windowBackgroundColor), lineWidth: 1))
            }
        }
    }
}
