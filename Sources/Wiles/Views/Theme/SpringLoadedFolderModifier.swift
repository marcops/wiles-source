import SwiftUI

public struct SpringLoadedFolderModifier: ViewModifier {
    let folderURL: URL
    let isDirectory: Bool
    var appState: AppState
    let onTargetedChanged: (Bool) -> Void
    
    @State private var isTargeted = false
    @State private var springTask: Task<Void, Never>? = nil

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
                appState.handleDrop(providers: providers, targetFolder: folderURL)
                return true
            }
            .onChange(of: isTargeted) { _, targeted in
                onTargetedChanged(targeted)
                guard isDirectory else { return }
                springTask?.cancel()
                if targeted {
                    springTask = Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(750))
                        if !Task.isCancelled {
                            withAnimation(MotionTokens.snappySpring) {
                                appState.navigateTo(folderURL)
                            }
                        }
                    }
                }
            }
    }
}

extension View {
    public func springLoadedFolder(
        folderURL: URL,
        isDirectory: Bool,
        appState: AppState,
        onTargetedChanged: @escaping (Bool) -> Void = { _ in }
    ) -> some View {
        self.modifier(
            SpringLoadedFolderModifier(
                folderURL: folderURL,
                isDirectory: isDirectory,
                appState: appState,
                onTargetedChanged: onTargetedChanged
            )
        )
    }
}
