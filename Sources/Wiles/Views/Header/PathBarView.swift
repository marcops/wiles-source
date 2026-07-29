import SwiftUI
import UniformTypeIdentifiers

struct PathSegment: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let url: URL
    let isFirst: Bool
}

struct PathBarView: View {
    var appState: AppState
    @FocusState private var isFocused: Bool
    
    var pathSegments: [PathSegment] {
        var res: [(name: String, url: URL)] = []
        var cur = appState.currentURL.standardizedFileURL
        var depth = 0
        while depth < 50 {
            let name = cur.path == "/" ? appState.tr(.root) : cur.lastPathComponent
            res.insert((name: name, url: cur), at: 0)
            if cur.path == "/" || cur.path.isEmpty { break }
            let parent = cur.deletingLastPathComponent()
            if parent.path == cur.path || parent == cur { break }
            cur = parent
            depth += 1
        }
        return res.enumerated().map { i, item in
            PathSegment(name: item.name, url: item.url, isFirst: i == 0)
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            if appState.isEditingPath {
                textFieldMode
            } else {
                breadcrumbMode
            }
        }
        .animation(.easeInOut(duration: 0.15), value: appState.isEditingPath)
    }
    
    private var textFieldMode: some View {
        @Bindable var appState = appState
        return HStack(spacing: 6) {
            Image(systemName: "folder").foregroundColor(.secondary)
            TextField(appState.tr(.enterPathPlaceholder), text: $appState.pathText)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onSubmit {
                    let url = URL(fileURLWithPath: (appState.pathText as NSString).expandingTildeInPath)
                    appState.navigateTo(url)
                    appState.isEditingPath = false
                }
                .onExitCommand {
                    appState.pathText = appState.currentURL.path
                    appState.isEditingPath = false
                }
                .onChange(of: isFocused) { _, focused in
                    if !focused {
                        appState.isEditingPath = false
                    }
                }
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(Color(NSColor.controlBackgroundColor)).cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.accentColor.opacity(0.6), lineWidth: 1.5))
        .background(ClickOutsideDetector {
            appState.isEditingPath = false
        })
        .onAppear { isFocused = true }
    }
    
    private var breadcrumbMode: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(pathSegments) { item in
                    breadcrumbPill(for: item)
                    if item.url != appState.currentURL.standardizedFileURL {
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, 4)
            .frame(height: 28)
        }
        .frame(height: 28)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5)).cornerRadius(6)
        .onTapGesture {
            appState.pathText = appState.currentURL.path
            appState.isEditingPath = true
        }
    }
    
    private func breadcrumbPill(for item: PathSegment) -> some View {
        let isHome = item.url.standardizedFileURL == FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
        return Button(action: { appState.navigateTo(item.url) }) {
            HStack(spacing: 4) {
                if isHome { Image(systemName: "house.fill").font(.system(size: 11)) }
                Text(item.name).font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 6)
            .frame(height: 22)
            .background(item.url == appState.currentURL ? Color.accentColor.opacity(0.2) : Color.clear)
            .foregroundColor(item.url == appState.currentURL ? .primary : .secondary)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers, targetFolder: item.url)
            return true
        }
    }
    
    private func handleDrop(providers: [NSItemProvider], targetFolder: URL) {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url else { return }
                Task { @MainActor in
                    try? FileSystemService.moveItem(at: url, toFolder: targetFolder)
                    appState.refreshCurrentDirectory()
                }
            }
        }
    }
}
