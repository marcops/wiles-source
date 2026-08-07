import SwiftUI

/// Attaches the file-info tooltip lazily: the (possibly disk-reading) metadata lookup only runs the
/// first time the pointer actually hovers this item, not on every body re-evaluation. AppKit already
/// applies its own delay before the tooltip bubble appears, and never updates one already on screen —
/// so `text` must be ready *before* that happens, not gated behind a second delay of our own.
private struct FileMetadataTooltipModifier: ViewModifier {
    let item: FileItem
    @State private var text: String?

    func body(content: Content) -> some View {
        content
            .help(text ?? item.name)
            .onHover { hovering in
                if hovering && text == nil {
                    Task { @MainActor in
                        text = await FileMetadataTooltipService.tooltip(for: item)
                    }
                }
            }
    }
}

extension View {
    func fileMetadataTooltip(_ item: FileItem) -> some View {
        modifier(FileMetadataTooltipModifier(item: item))
    }
}
