import SwiftUI

/// Presented as a sheet (`windowUIState.showSettingsSheet`, wired in `MainContentView`, triggered
/// from the App menu's `⌘,` item in `WilesApp.swift`) rather than a `Settings { }` scene — a real
/// scene always comes with its own native title bar/traffic-light window chrome, which fought this
/// header/footer chrome no matter how it was stripped. A sheet has none of that chrome to begin
/// with, so it follows the exact same header/divider/content/divider/footer pattern as every other
/// modal in the app (`HelpSheet`, `AboutSheet`, etc. — see AGENTS.md rule 30) with no extra work.
struct SettingsView: View {
    @Environment(\.dismiss)
    private var dismiss
    var appState: AppState

    private enum Tab: CaseIterable, Identifiable {
        case general, appearance, sidebar, advanced
        var id: Self {
            self
        }
    }

    @State private var selectedTab: Tab = .general

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()

            content

            Divider()
            footerView
        }
        .frame(width: 480, height: 470)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var headerView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(nsImage: NSApplication.shared.applicationIconImage ?? NSWorkspace.shared.icon(for: .folder))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.tr(.wilesFileManager))
                        .font(.system(size: 16, weight: .bold))
                    Text(appState.tr(.settingsHeaderSubtitle))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            tabSwitcher
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    /// A hand-rolled icon-over-title tab row instead of `Picker(.segmented)`: macOS's segmented
    /// control silently drops the icon from a `Label` even with `.labelStyle(.titleAndIcon)`
    /// applied, showing text only. This mirrors the classic macOS Preferences toolbar tab look
    /// (icon above label) while still living inside our own header instead of a native `NSToolbar`.
    private var tabSwitcher: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases) { tab in
                tabButton(for: tab)
            }
        }
    }

    /// A real `Button` on macOS, even with `.contentShape(Rectangle())` matched exactly to its own
    /// frame, keeps registering clicks only over the label's actual rendered (non-transparent)
    /// content — the `Color.clear`-backed padding around the icon/text stays dead even though it's
    /// visually inside the 64x44 pill. `.contentShape` reliably drives SwiftUI's own gesture
    /// recognizers but not `Button`'s AppKit-backed click routing here (see AGENTS.md rule 33), so
    /// this uses a plain view + `.onTapGesture` instead — that combination does respect
    /// `.contentShape` for the *entire* frame, matched exactly to the visible pill (no outset: see
    /// the overlap bug this had previously, also documented in rule 33).
    private static let tabButtonSize = CGSize(width: 64, height: 44)

    private func tabButton(for tab: Tab) -> some View {
        let isSelected = selectedTab == tab
        let size = Self.tabButtonSize
        return VStack(spacing: 4) {
            Image(systemName: icon(for: tab))
                .font(.system(size: 16))
            Text(title(for: tab))
                .font(.system(size: 10))
        }
        .foregroundColor(isSelected ? Color.accentColor : .secondary)
        .frame(width: size.width, height: size.height)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear))
        .contentShape(Rectangle())
        .onTapGesture {
            selectedTab = tab
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text(title(for: tab)))
    }

    private var content: some View {
        Group {
            switch selectedTab {
            case .general:
                GeneralSettingsView(appState: appState)
            case .appearance:
                AppearanceSettingsView(appState: appState)
            case .sidebar:
                SidebarSettingsView(appState: appState)
            case .advanced:
                AdvancedSettingsView(appState: appState)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var footerView: some View {
        HStack {
            Spacer()
            Button(appState.tr(.done)) { dismiss() }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func title(for tab: Tab) -> String {
        switch tab {
        case .general: appState.tr(.settingsGeneralTab)
        case .appearance: appState.tr(.settingsAppearanceTab)
        case .sidebar: appState.tr(.settingsSidebarTab)
        case .advanced: appState.tr(.settingsAdvancedTab)
        }
    }

    private func icon(for tab: Tab) -> String {
        switch tab {
        case .general: "gearshape"
        case .appearance: "paintbrush"
        case .sidebar: "sidebar.left"
        case .advanced: "slider.horizontal.3"
        }
    }
}
