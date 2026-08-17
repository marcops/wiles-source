import SwiftUI

/// Icon source for `ModalScaffoldView`'s header. Every case renders into the same fixed-size
/// slot so header weight looks identical regardless of which kind of icon a given modal uses.
enum ModalIcon {
    case appIcon
    case symbol(String)
    case image(NSImage)

    @MainActor
    @ViewBuilder
    func view(size: CGFloat) -> some View {
        switch self {
        case .appIcon:
            Image(nsImage: NSApplication.shared.applicationIconImage ?? NSWorkspace.shared.icon(for: .folder))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        case let .symbol(name):
            Image(systemName: name)
                .font(.system(size: size * LayoutTokens.modalSymbolIconScale))
                .foregroundColor(.accentColor)
                .frame(width: size, height: size)
        case let .image(nsImage):
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        }
    }
}
