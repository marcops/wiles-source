import SwiftUI

/// Icon source for `ModalScaffoldView`'s header. Every case renders into the same fixed-size
/// slot so header weight looks identical regardless of which kind of icon a given modal uses.
enum ModalIcon {
    private static let symbolIconScale: CGFloat = 0.5

    case appIcon
    case symbol(String)
    case image(NSImage)

    /// Resolved app icon image, shared by the `.appIcon` case below and any caller (e.g.
    /// `AboutSheet`) that needs to render the same icon outside the header slot.
    @MainActor static var resolvedAppIcon: NSImage {
        NSApplication.shared.applicationIconImage ?? NSWorkspace.shared.icon(for: .folder)
    }

    @MainActor
    @ViewBuilder
    func view(size: CGFloat) -> some View {
        switch self {
        case .appIcon:
            Image(nsImage: Self.resolvedAppIcon)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        case let .symbol(name):
            Image(systemName: name)
                .font(.system(size: size * Self.symbolIconScale))
                .foregroundColor(.accentColor)
                .frame(width: size, height: size)
        case let .image(nsImage):
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        }
    }
}
