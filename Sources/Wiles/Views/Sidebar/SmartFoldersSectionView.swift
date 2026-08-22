import SwiftUI

struct SmartFoldersSectionView: View {
    var appState: AppState
    @Binding var isExpanded: Bool
    @Binding var renamingSmartFolderID: SmartFolder.ID?
    @Binding var smartFolderRenameText: String
    var isRenameFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if appState.preferences.showSidebarSectionTitles {
                SidebarSectionHeaderView(
                    title: appState.tr(.smartFolders), identifierKey: "SMART_FOLDERS", appState: appState, isExpanded: $isExpanded)
            }
            if !appState.preferences.showSidebarSectionTitles || isExpanded {
                ForEach(appState.preferences.smartFolders) { folder in
                    smartFolderRow(folder: folder)
                }
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

    /// See AGENTS.md rule 33: a real `Button` on macOS does not reliably honor `.contentShape`
    /// for composite (icon + text) label content, so this uses a plain view + `.onTapGesture`.
    private func smartFolderButtonRow(folder: SmartFolder) -> some View {
        let isSel = appState.smartFolder.activeFolderID == folder.id
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
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(isSel ? Color.accentColor.opacity(0.18) : Color.clear)
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            runSmartFolder(folder)
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(folder.name)
        .accessibilityHint(appState.tr(.folder))
        .padding(.horizontal, 8)
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
            Button(appState.tr(.moveToTrash), role: .destructive) {
                appState.removeSmartFolder(folder)
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
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + AsyncDelayTokens.searchFieldFocusDelay) {
                        isRenameFocused.wrappedValue = true
                    }
                }
                .onSubmit { commitSmartFolderRename(folder) }
                .onExitCommand { renamingSmartFolderID = nil }
        }
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
        appState.renameSmartFolder(folder, to: smartFolderRenameText)
        renamingSmartFolderID = nil
    }

    private func runSmartFolder(_ folder: SmartFolder) {
        appState.runSmartFolder(folder)
    }
}
