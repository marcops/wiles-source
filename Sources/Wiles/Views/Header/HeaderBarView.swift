import SwiftUI
import AppKit

struct HeaderBarView: View {
    var appState: AppState
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Reserved spacer for native macOS window traffic lights (Red/Yellow/Green)
            Spacer().frame(width: 60)
            
            historyButtons
            if appState.isSearching {
                searchField.frame(maxWidth: .infinity)
            } else {
                PathBarView(appState: appState).frame(maxWidth: .infinity)
            }
            rightControls
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .background(Color(NSColor.windowBackgroundColor))
        .background(TrafficLightRepositioner(offsetY: 6))
    }
    
    private var historyButtons: some View {
        HStack(spacing: 4) {
            Button(action: { appState.goBack() }) {
                Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 28).background(Color(NSColor.controlBackgroundColor)).cornerRadius(6)
            }
            .buttonStyle(.plain).disabled(appState.historyBack.isEmpty)
            .opacity(appState.historyBack.isEmpty ? 0.4 : 1.0)
            .keyboardShortcut("[", modifiers: .command)
            
            Button(action: { appState.goForward() }) {
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 28).background(Color(NSColor.controlBackgroundColor)).cornerRadius(6)
            }
            .buttonStyle(.plain).disabled(appState.historyForward.isEmpty)
            .opacity(appState.historyForward.isEmpty ? 0.4 : 1.0)
            .keyboardShortcut("]", modifiers: .command)
            
            Button(action: { appState.goUp() }) {
                Image(systemName: "arrow.up").font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 28).background(Color(NSColor.controlBackgroundColor)).cornerRadius(6)
            }
            .buttonStyle(.plain).help(appState.tr(.parentFolder))
            .keyboardShortcut(.upArrow, modifiers: .command)
            
            Button(action: { appState.refreshCurrentDirectory() }) {
                Image(systemName: "arrow.clockwise").font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 28).background(Color(NSColor.controlBackgroundColor)).cornerRadius(6)
            }
            .buttonStyle(.plain).help("\(appState.tr(.refresh)) (Cmd+R)")
            .keyboardShortcut("r", modifiers: .command)
        }
    }
    
    private var rightControls: some View {
        HStack(spacing: 8) {
            searchButton
            viewSwitcher
            sortMenu
            optionsMenu
        }
    }
    
    private var searchField: some View {
        @Bindable var appState = appState
        return HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            TextField("\(appState.tr(.searchPlaceholder)) \(appState.currentURL.lastPathComponent)...", text: $appState.searchQuery)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        isSearchFocused = true
                    }
                }
                .onSubmit {
                    NSApp.keyWindow?.makeFirstResponder(nil)
                }
                .onExitCommand {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        appState.isSearching = false
                        appState.searchQuery = ""
                    }
                }
            if !appState.searchQuery.isEmpty {
                Button(action: { appState.searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(Color(NSColor.controlBackgroundColor)).cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.accentColor.opacity(0.6), lineWidth: 1.5))
        .background(ClickOutsideDetector {
            if appState.isSearching && appState.searchQuery.isEmpty {
                withAnimation(.easeInOut(duration: 0.15)) {
                    appState.isSearching = false
                }
            }
        })
    }

    private var searchButton: some View {
        Button(action: {
            withAnimation {
                appState.isSearching.toggle()
                if !appState.isSearching { appState.searchQuery = "" }
            }
        }) {
            Image(systemName: "magnifyingglass").font(.system(size: 13, weight: .medium))
                .frame(width: 30, height: 28)
                .background(appState.isSearching ? Color.accentColor.opacity(0.25) : Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
        }
        .buttonStyle(.plain).help("\(appState.tr(.searchPlaceholder)) (Cmd+F)")
        .keyboardShortcut("f", modifiers: .command)
    }
    
    private var viewSwitcher: some View {
        HStack(spacing: 2) {
            Button(action: { appState.viewMode = .grid }) {
                Image(systemName: "square.grid.2x2").font(.system(size: 12))
                    .frame(width: 26, height: 24)
                    .background(appState.viewMode == .grid ? Color.accentColor : Color.clear)
                    .foregroundColor(appState.viewMode == .grid ? .white : .primary).cornerRadius(4)
            }
            .buttonStyle(.plain)
            
            Button(action: { appState.viewMode = .list }) {
                Image(systemName: "list.bullet").font(.system(size: 12))
                    .frame(width: 26, height: 24)
                    .background(appState.viewMode == .list ? Color.accentColor : Color.clear)
                    .foregroundColor(appState.viewMode == .list ? .white : .primary).cornerRadius(4)
            }
            .buttonStyle(.plain)
        }
        .padding(2).background(Color(NSColor.controlBackgroundColor)).cornerRadius(6)
    }
    
    private var sortMenu: some View {
        @Bindable var appState = appState
        return Menu {
            Picker(appState.tr(.sortBy), selection: $appState.sortOption) {
                ForEach(SortOption.allCases) { opt in Text(opt.rawValue).tag(opt) }
            }
            .onChange(of: appState.sortOption) { _, _ in appState.refreshCurrentDirectory() }
            
            Divider()
            
            Toggle(appState.tr(.ascending), isOn: $appState.sortAscending)
                .onChange(of: appState.sortAscending) { _, _ in appState.refreshCurrentDirectory() }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down").font(.system(size: 12))
                Text(appState.sortOption.rawValue).font(.system(size: 12))
            }
            .frame(height: 28).padding(.horizontal, 8).background(Color(NSColor.controlBackgroundColor)).cornerRadius(6)
        }
        .menuStyle(.borderlessButton)
    }
    
    private var optionsMenu: some View {
        @Bindable var appState = appState
        return Menu {
            Menu(appState.tr(.translucentLevel)) {
                ForEach([0, 20, 40, 50, 60, 80, 100], id: \.self) { level in
                    Button(action: { appState.translucentLevel = level }) {
                        HStack {
                            Text("\(level)%")
                            if appState.translucentLevel == level { Image(systemName: "checkmark") }
                        }
                    }
                }
            }
            Divider()
            Toggle(appState.navigationMode == .gnome ? appState.tr(.showHiddenFilesGnome) : appState.tr(.showHiddenFilesMac), isOn: $appState.showHiddenFiles)
                .onChange(of: appState.showHiddenFiles) { _, _ in appState.refreshCurrentDirectory() }
            Toggle(appState.tr(.showFavorites), isOn: $appState.showFavorites)
            Toggle(appState.tr(.showMacSection), isOn: $appState.showMacSection)
            if appState.showMacSection {
                Toggle(appState.tr(.showRecents), isOn: $appState.showRecents)
            }
            Picker(appState.tr(.sidebarMode), selection: $appState.sidebarMode) {
                ForEach(SidebarMode.allCases) { mode in Text(mode.rawValue).tag(mode) }
            }
            Divider()
            Picker(appState.tr(.shortcutMode), selection: $appState.navigationMode) {
                ForEach(NavigationMode.allCases) { mode in Text(mode.rawValue).tag(mode) }
            }
            Picker(appState.tr(.language), selection: $appState.appLanguage) {
                ForEach(AppLanguage.allCases) { lang in Text(lang.displayName).tag(lang) }
            }
            Divider()
            Toggle(appState.showPreviewSidebar ? "Hide Preview" : appState.tr(.showPreviewSidebar), isOn: $appState.showPreviewSidebar)
            Toggle(appState.showFooter ? appState.tr(.hideStatusBar) : appState.tr(.showStatusBar), isOn: $appState.showFooter)
            Divider()
            Button(appState.tr(.copyPath)) {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(appState.currentURL.path, forType: .string)
            }
            Button("\(appState.tr(.newFolder)) (Shift+Cmd+N)") {
                appState.showNewFolderSheet = true
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            Divider()
            Button("\(appState.tr(.helpShortcuts))...") {
                appState.showHelpSheet = true
            }
        } label: {
            Image(systemName: "line.3.horizontal").font(.system(size: 13, weight: .medium))
                .frame(width: 30, height: 28).background(Color(NSColor.controlBackgroundColor)).cornerRadius(6)
        }
        .menuStyle(.borderlessButton)
    }
}

struct TrafficLightRepositioner: NSViewRepresentable {
    let offsetY: CGFloat

    func makeNSView(context: Context) -> NSView {
        let view = RepositionerView()
        view.offsetY = offsetY
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? RepositionerView {
            view.offsetY = offsetY
        }
    }

    class RepositionerView: NSView {
        var offsetY: CGFloat = 6

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            reposition()
        }

        override func layout() {
            super.layout()
            reposition()
        }

        private func reposition() {
            guard let window = self.window,
                  let closeBtn = window.standardWindowButton(.closeButton),
                  let superview = closeBtn.superview else { return }

            let buttons = [
                window.standardWindowButton(.closeButton),
                window.standardWindowButton(.miniaturizeButton),
                window.standardWindowButton(.zoomButton)
            ]

            for btn in buttons {
                guard let b = btn else { continue }
                var f = b.frame
                f.origin.y = (superview.bounds.height - f.height) / 2 - offsetY
                b.setFrameOrigin(f.origin)
            }
        }
    }
}
