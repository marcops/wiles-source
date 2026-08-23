import GitBeacon
import SwiftUI

public struct SymlinkSheetView: View {
    private static let sheetWidth: CGFloat = 380

    let item: FileItem
    var appState: AppState

    @Environment(\.dismiss)
    private var dismiss
    @FocusState private var isNameFocused: Bool

    @State private var symlinkName: String = ""
    @State private var mode: SymlinkMode = .absolute
    @State private var collisionWarning: String?

    public init(item: FileItem, appState: AppState) {
        self.item = item
        self.appState = appState
    }

    public var body: some View {
        ModalScaffoldView(
            icon: .symbol("link"),
            title: appState.tr(.createSymbolicLink),
            subtitle: appState.tr(.symlinkSubtitle),
            width: Self.sheetWidth,
            primaryButton: ModalFooterButton(
                title: appState.tr(.createLink),
                isEnabled: !symlinkName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                    createSymlink()
                },
            secondaryButton: ModalFooterButton(title: appState.tr(.cancel)) { dismiss() },
            content: { formContent })
            .onAppear {
                symlinkName = Self.defaultSymlinkName(for: item, suffix: appState.tr(.symlinkNameSuffix))
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
                    Text(appState.tr(mode.l10nKey)).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel(appState.tr(.linkType))
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
                .accessibilityLabel(appState.tr(.symlinkNameLabel))
            if let collisionWarning {
                Text(collisionWarning)
                    .font(.system(size: 11))
                    .foregroundColor(.red)
            }
        }
    }

    /// Inserts the "link" suffix before the extension so `report.pdf` becomes `report link.pdf`
    /// rather than `report.pdf link`.
    private static func defaultSymlinkName(for item: FileItem, suffix: String) -> String {
        guard !item.isDirectory else { return "\(item.name) \(suffix)" }
        let ext = item.url.pathExtension
        let base = item.url.deletingPathExtension().lastPathComponent
        return ext.isEmpty ? "\(base) \(suffix)" : "\(base) \(suffix).\(ext)"
    }

    private func createSymlink() {
        let trimmedName = symlinkName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let destinationFolder = appState.navigation.currentURL
        // fileExists(atPath:) is fine inline for a local path; under /Volumes/ it hops off @MainActor,
        // mirroring FolderPickerSheet.commitPathText.
        // swiftlint:disable:next no_naive_path_prefix_check — "/Volumes/" literal already has a trailing "/", can't collide with a sibling mount name.
        if destinationFolder.path.hasPrefix("/Volumes/") {
            Task {
                let collides = await Task.detached(priority: .userInitiated) {
                    FileManager.default.fileExists(atPath: destinationFolder.appendingPathComponent(trimmedName).path)
                }.value
                finishCreatingSymlink(name: trimmedName, destinationFolder: destinationFolder, collides: collides)
            }
            return
        }
        let collides = FileManager.default.fileExists(atPath: destinationFolder.appendingPathComponent(trimmedName).path)
        finishCreatingSymlink(name: trimmedName, destinationFolder: destinationFolder, collides: collides)
    }

    private func finishCreatingSymlink(name: String, destinationFolder: URL, collides: Bool) {
        guard !collides else {
            collisionWarning = appState.tr(.symlinkNameCollisionWarning)
            return
        }
        collisionWarning = nil
        do {
            let createdURL = try SymlinkService.createSymlink(
                targetURL: item.url,
                destinationFolder: destinationFolder,
                symlinkName: name,
                mode: mode)
            appState.refreshCurrentDirectory()
            appState.selection.selectedURLs = [createdURL]
            dismiss()
        } catch {
            ErrorReporter.report(error, context: "Creating symbolic link")
            appState.showError(error.localizedDescription)
        }
    }
}
