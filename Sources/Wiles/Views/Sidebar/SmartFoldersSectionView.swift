import SwiftUI

struct SmartFoldersSectionView: View {
    var appState: AppState
    @Binding var isExpanded: Bool
    @Binding var renamingSmartFolderID: SmartFolder.ID?
    @Binding var smartFolderRenameText: String
    var isRenameFocused: FocusState<Bool>.Binding
    @State private var rightClickedFolderID: SmartFolder.ID?
    @State private var pendingDeleteFolder: SmartFolder?

    var body: some View {
        SidebarSectionContainer(
            appState: appState, title: appState.tr(.smartFolders), identifierKey: "SMART_FOLDERS", isExpanded: $isExpanded) {
                ForEach(appState.preferences.smartFolders) { folder in
                    smartFolderRow(folder: folder)
                }
            }
            .confirmationDialog(
                appState.tr(.removeSmartFolderConfirm), isPresented: Binding(
                    get: { pendingDeleteFolder != nil },
                    set: {
                        if !$0 {
                            pendingDeleteFolder = nil
                        }
                    }),
                titleVisibility: .visible) {
                    Button(appState.tr(.deleteSmartFolder), role: .destructive) {
                        if let folder = pendingDeleteFolder {
                            appState.removeSmartFolder(folder)
                        }
                        pendingDeleteFolder = nil
                    }
            }
    }

    @ViewBuilder
    private func smartFolderRow(folder: SmartFolder) -> some View {
        if renamingSmartFolderID == folder.id {
            smartFolderRenameField(folder: folder)
        } else {
            smartFolderButtonRow(folder: folder)
        }
    }

    /// See SWIFT_LANG_RULES.md "Custom Tappable Content MUST Have an Explicit `.contentShape`": a real `Button` on macOS does not reliably honor
    /// `.contentShape`
    /// for composite (icon + text) label content, so this uses a plain view + `.onTapGesture`.
    private func smartFolderButtonRow(folder: SmartFolder) -> some View {
        let isSel = appState.smartFolder.activeFolderID == folder.id || rightClickedFolderID == folder.id
        return HStack(spacing: 10) {
            Image(systemName: folder.icon)
                .font(.system(size: 15))
                .foregroundColor(.accentColor)
                .frame(width: 20, height: 20)
            Text(folder.name)
                .font(.system(size: 13, weight: isSel ? .semibold : .regular))
                .lineLimit(1)
            Spacer()
        }
        .sidebarRowChrome(isSelected: isSel)
        .onTapGesture {
            appState.runSmartFolder(folder)
        }
        .accessibilityAddTraits(isSel ? [.isButton, .isSelected] : [.isButton])
        .accessibilityLabel(folder.name)
        .accessibilityHint(appState.tr(.smartFolderHint))
        .padding(.horizontal, 8)
        .overlay(
            RightClickDetector { rightClickedFolderID = folder.id })
        .contextMenu {
            Button(appState.tr(.rename)) {
                smartFolderRenameText = folder.name
                renamingSmartFolderID = folder.id
            }
            Button(appState.tr(.updateSmartFolderSearch)) {
                appState.updateSmartFolderQuery(folder, to: appState.selection.searchQuery)
            }
            .disabled(appState.selection.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty)
            Divider()
            Button(appState.tr(.deleteSmartFolder), role: .destructive) {
                pendingDeleteFolder = folder
            }
        }
    }

    private func smartFolderRenameField(folder: SmartFolder) -> some View {
        HStack(spacing: 10) {
            Image(systemName: folder.icon)
                .font(.system(size: 15))
                .foregroundColor(.accentColor)
                .frame(width: 20, height: 20)
            TextField("", text: $smartFolderRenameText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused(isRenameFocused)
                .task {
                    try? await Task.sleep(for: AsyncDelayTokens.searchFieldFocusDelay)
                    isRenameFocused.wrappedValue = true
                }
                .onSubmit { commitSmartFolderRename(folder) }
                .onExitCommand { renamingSmartFolderID = nil }
        }
        // Mirrors the button row's total inset so the row doesn't shift on entering rename mode:
        // sidebarRowChrome's 10h/7v inner padding, then the button row's 8h outer padding.
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .padding(.horizontal, 8)
        .onChange(of: isRenameFocused.wrappedValue) { _, focused in
            if !focused {
                commitSmartFolderRename(folder)
            }
        }
    }

    private func commitSmartFolderRename(_ folder: SmartFolder) {
        guard renamingSmartFolderID == folder.id else { return }
        // An empty/whitespace name just cancels the rename (the store would no-op it silently
        // otherwise, leaving the field to revert with no explanation).
        let trimmed = smartFolderRenameText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            appState.renameSmartFolder(folder, to: trimmed)
        }
        renamingSmartFolderID = nil
    }
}
