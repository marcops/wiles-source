import SwiftUI
import AppKit

struct ShortcutsHUDOverlay: View {
    var appState: AppState
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .onTapGesture {
                    withAnimation(MotionTokens.snappySpring) {
                        appState.showShortcutsHUD = false
                    }
                }
            
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "keyboard")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.accentColor)
                    Text(appState.tr(.shortcutsCheatsheetTitle))
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                    Button(action: {
                        withAnimation(MotionTokens.snappySpring) {
                            appState.showShortcutsHUD = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                Text(appState.navigationMode.shortName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.15))
                    .cornerRadius(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                ScrollView {
                    VStack(spacing: 12) {
                        shortcutGroup(title: appState.tr(.shortcutsNav), items: navigationShortcuts)
                        shortcutGroup(title: appState.tr(.shortcutsFileActions), items: fileActionsShortcuts)
                        shortcutGroup(title: appState.tr(.shortcutsSystem), items: systemShortcuts)
                    }
                }
            }
            .padding(20)
            .frame(width: 380, height: 420)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(NSColor.windowBackgroundColor).opacity(0.85))
                    .background(TranslucentVisualEffectView(material: .hudWindow).cornerRadius(16))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 15, x: 0, y: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var navigationShortcuts: [(String, String)] {
        if appState.navigationMode == .macOS {
            return [
                (appState.tr(.actNavBackForward), "⌘ [  /  ⌘ ]"),
                (appState.tr(.actParentFolder), "⌘ ↑"),
                (appState.tr(.shortcutsOpenFolder), "⌘ ↓")
            ]
        } else {
            return [
                (appState.tr(.actNavBackForward), "⌘ [  /  ⌘ ]"),
                (appState.tr(.actParentFolder), "Backspace"),
                (appState.tr(.shortcutsOpenFolder), "Enter")
            ]
        }
    }
    
    private var fileActionsShortcuts: [(String, String)] {
        let renameKey = appState.navigationMode == .gnome ? "F2" : "Return"
        return [
            (appState.tr(.actCopyShortcut), "⌘ C"),
            (appState.tr(.actCutShortcut), "⌘ X"),
            (appState.tr(.actPasteShortcut), "⌘ V"),
            (appState.tr(.shortcutsRename), renameKey),
            (appState.tr(.actQuickLook), "Space"),
            (appState.tr(.actItemProperties), "⌘ I"),
            (appState.tr(.actNewFolderShortcut), "⌘ Shift N"),
            (appState.tr(.actMoveTrash), "⌘ Delete")
        ]
    }
    
    private var systemShortcuts: [(String, String)] {
        let hiddenKey = appState.navigationMode == .gnome ? "Ctrl + H" : "⌘ Shift ."
        return [
            (appState.tr(.actSearch), "⌘ F"),
            (appState.tr(.shortcutsToggleHidden), hiddenKey),
            (appState.tr(.actUndo), "⌘ Z"),
            (appState.tr(.actRedo), "⌘ Shift Z"),
            (appState.tr(.shortcutsToggleOverlay), "⌘ /")
        ]
    }
    
    private func shortcutGroup(title: String, items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.bottom, 2)
            
            ForEach(items, id: \.0) { item in
                HStack {
                    Text(item.0)
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                    Spacer()
                    Text(item.1)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12))
                        .cornerRadius(4)
                }
            }
            Divider().padding(.vertical, 4)
        }
    }
}
