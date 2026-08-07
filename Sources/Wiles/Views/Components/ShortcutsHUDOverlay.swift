import SwiftUI
import AppKit

struct ShortcutsHUDOverlay: View {
    var appState: AppState
    @Binding var isPresented: Bool
    @State private var previewMode: NavigationMode

    init(appState: AppState, isPresented: Binding<Bool>) {
        self.appState = appState
        self._isPresented = isPresented
        _previewMode = State(initialValue: appState.navigationMode)
    }

    var body: some View {
        ZStack {
            // `MainContentView` applies `.ignoresSafeArea(.all, edges: .top)` so `HeaderBarView`
            // can extend up into the hidden-title-bar region at the very top of the window. This
            // dimming backdrop needs the same treatment, or that same top strip stays undimmed
            // while everything below it darkens.
            Color.black.opacity(0.3)
                .ignoresSafeArea(.all, edges: .top)
                .onTapGesture {
                    withAnimation(MotionTokens.snappySpring) {
                        isPresented = false
                    }
                }

            VStack(spacing: 16) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                modeTabRow
                    .padding(.horizontal, 20)
                Divider()
                shortcutColumns
                Divider()
                footer
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
            .frame(minWidth: 300, maxWidth: 400, minHeight: 340, maxHeight: 460)
            .background(
                ZStack {
                    TranslucentVisualEffectView(material: .hudWindow)
                    Color(NSColor.windowBackgroundColor).opacity(0.85)
                }
            )
            // A single `.clipShape` for the whole composited card (content + background layers)
            // instead of separate `.cornerRadius()` calls on each background layer — mismatched
            // per-layer corner clipping is what caused the rounded top area (where the header sits)
            // to render inconsistently against the rest of the card.
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 15, x: 0, y: 8)
            Button("") {
                withAnimation(MotionTokens.snappySpring) {
                    isPresented = false
                }
            }
            .keyboardShortcut(.escape, modifiers: [])
            .hidden()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack {
            Image(systemName: "keyboard")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(appState.tr(.shortcutsCheatsheetTitle))
                    .font(.system(size: 16, weight: .bold))
                Text(appState.tr(.shortcutsCheatsheetSubtitle))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    private var modeTabRow: some View {
        HStack(spacing: 8) {
            modeTabButton(.gnome)
            modeTabButton(.macOS)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func modeTabButton(_ mode: NavigationMode) -> some View {
        let isSelected = previewMode == mode
        let isActual = appState.navigationMode == mode
        return Button {
            withAnimation(MotionTokens.snappySpring) { previewMode = mode }
        } label: {
            HStack(spacing: 5) {
                Text(appState.tr(mode.l10nKey))
                    .font(.system(size: 11, weight: .semibold))
                if isActual {
                    Text(appState.tr(.shortcutsCurrentModeBadge).uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.25))
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.08))
            .foregroundColor(isSelected ? Color.accentColor : Color.primary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(appState.tr(mode.l10nKey))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button(appState.tr(.done)) {
                withAnimation(MotionTokens.snappySpring) {
                    isPresented = false
                }
            }
            .keyboardShortcut(.defaultAction)
        }
    }

    private var shortcutColumns: some View {
        ScrollView {
            VStack(spacing: 12) {
                shortcutGroup(title: appState.tr(.shortcutsNav), items: navigationShortcuts)
                shortcutGroup(title: appState.tr(.shortcutsFileActions), items: fileActionsShortcuts)
                shortcutGroup(title: appState.tr(.shortcutsSystem), items: systemShortcuts)
            }
            .padding(.leading, 20)
            .padding(.trailing, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var navigationShortcuts: [(String, String)] {
        if previewMode == .macOS {
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
        let renameKey = previewMode == .gnome ? "F2" : "Return"
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
        let hiddenKey = previewMode == .gnome ? "Ctrl + H" : "⌘ Shift ."
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
                .padding(.top, 4)
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
