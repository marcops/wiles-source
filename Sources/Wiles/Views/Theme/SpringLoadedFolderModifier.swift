import SwiftUI

public struct SpringLoadedFolderModifier: ViewModifier {
    let folderURL: URL
    let isDirectory: Bool
    var appState: AppState
    let onTargetedChanged: (Bool) -> Void

    @Environment(WindowUIState.self)
    private var windowUIState
    @State private var isTargeted = false
    @State private var springTask: Task<Void, Never>?

    public init(folderURL: URL, isDirectory: Bool, appState: AppState, onTargetedChanged: @escaping (Bool) -> Void) {
        self.folderURL = folderURL
        self.isDirectory = isDirectory
        self.appState = appState
        self.onTargetedChanged = onTargetedChanged
    }

    public func body(content: Content) -> some View {
        content
            .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                springTask?.cancel()
                guard isDirectory else { return false }
                appState.handleDrop(providers: providers, targetFolder: folderURL, windowUIState: windowUIState)
                return true
            }
            .onChange(of: isTargeted) { _, targeted in
                onTargetedChanged(targeted)
                guard isDirectory else { return }
                springTask?.cancel()
                if targeted {
                    springTask = Task { @MainActor in
                        try? await Task.sleep(for: AsyncDelayTokens.springLoadedFolderDelay)
                        if !Task.isCancelled {
                            withAnimation(MotionTokens.snappySpring) {
                                appState.navigateTo(folderURL)
                            }
                        }
                    }
                }
            }
            .onDisappear {
                // Without this, a pending spring-load delay outlives a row that scrolled out of
                // the hierarchy mid-drag and still fires `navigateTo` on a now-invisible view.
                springTask?.cancel()
            }
    }
}

public extension View {
    func springLoadedFolder(
        folderURL: URL,
        isDirectory: Bool,
        appState: AppState,
        onTargetedChanged: @escaping (Bool) -> Void = { _ in }) -> some View {
        modifier(
            SpringLoadedFolderModifier(
                folderURL: folderURL,
                isDirectory: isDirectory,
                appState: appState,
                onTargetedChanged: onTargetedChanged))
    }
}
