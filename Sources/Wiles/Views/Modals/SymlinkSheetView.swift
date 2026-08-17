import GitBeacon
import SwiftUI

public struct SymlinkSheetView: View {
    let item: FileItem
    var appState: AppState

    @Environment(\.dismiss)
    private var dismiss
    @FocusState private var isNameFocused: Bool

    @State private var symlinkName: String = ""
    @State private var mode: SymlinkMode = .absolute

    public init(item: FileItem, appState: AppState) {
        self.item = item
        self.appState = appState
    }

    public var body: some View {
        ModalScaffoldView(
            icon: .symbol("link"),
            title: appState.tr(.createSymbolicLink),
            width: 380,
            primaryButton: ModalFooterButton(
                title: appState.tr(.createLink),
                isEnabled: !symlinkName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                    createSymlink()
                },
            secondaryButton: ModalFooterButton(title: appState.tr(.cancel)) { dismiss() },
            content: { formContent })
            .onAppear {
                symlinkName = item.name + " link"
                isNameFocused = true
            }
    }

    private var formContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            modePickerSection
            nameInputSection
        }
        .padding(20)
    }

    private var modePickerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(appState.tr(.linkType))
                .font(.subheadline)
                .foregroundColor(.secondary)
            Picker("", selection: $mode) {
                ForEach(SymlinkMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var nameInputSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(appState.tr(.symlinkNameLabel))
                .font(.subheadline)
                .foregroundColor(.secondary)
            TextField("", text: $symlinkName)
                .textFieldStyle(.roundedBorder)
                .focused($isNameFocused)
                .onSubmit { createSymlink() }
        }
    }

    private func createSymlink() {
        do {
            let createdURL = try SymlinkService.createSymlink(
                targetURL: item.url,
                destinationFolder: appState.navigation.currentURL,
                symlinkName: symlinkName,
                mode: mode)
            appState.refreshCurrentDirectory()
            appState.selectedURLs = [createdURL]
            dismiss()
        } catch {
            ErrorReporter.report(error, context: "Creating symbolic link")
            appState.showError(error.localizedDescription)
            dismiss()
        }
    }
}
