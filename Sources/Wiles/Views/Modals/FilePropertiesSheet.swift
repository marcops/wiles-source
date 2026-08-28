import AppKit
import GitBeacon
import SwiftUI

struct FilePropertiesSheet: View {
    private static let headerIconSizeLarge: CGFloat = 64.0
    private static let sheetWidth: CGFloat = 400.0
    private static let sheetHeight: CGFloat = 500.0

    let item: FileItem
    var appState: AppState
    @Environment(\.dismiss)
    private var dismiss

    @State private var detailedProps: DetailedFileProperties?

    @State private var isGeneralExpanded = true
    @State private var isMoreInfoExpanded = true
    @State private var isExifExpanded = true
    @State private var isPermissionsExpanded = true
    @State private var permissions = POSIXPermissions(posixPermissions: 0o644)
    @State private var lastAppliedPermissions: POSIXPermissions?
    @State private var hasPermissions = false
    @State private var exifData: ExifMetadata?
    @State private var showDiscardConfirmation = false
    @State private var applyToEnclosedItems = false
    @State private var showRecursivePermissionsConfirmation = false
    @State private var isApplyingPermissions = false
    @State private var applyPermissionsResult: String?

    private var hasPendingPermissionChanges: Bool {
        hasPermissions && permissions != (lastAppliedPermissions ?? permissions)
    }

    var body: some View {
        ModalScaffoldView(
            icon: .image(item.icon),
            title: item.name,
            subtitle: "\(kindText) • \(item.formattedSize)",
            iconSize: Self.headerIconSizeLarge,
            width: Self.sheetWidth,
            height: Self.sheetHeight,
            primaryButton: ModalFooterButton(title: appState.tr(.close)) { attemptClose() },
            content: { contentArea })
            .confirmationDialog(appState.tr(.discardPermissionChangesMessage), isPresented: $showDiscardConfirmation, titleVisibility: .visible) {
                Button(appState.tr(.discard), role: .destructive) { dismiss() }
                Button(appState.tr(.cancel), role: .cancel) { }
            }
            .confirmationDialog(
                appState.tr(.applyToEnclosedItemsConfirmMessage),
                isPresented: $showRecursivePermissionsConfirmation,
                titleVisibility: .visible) {
                    Button(appState.tr(.apply), role: .destructive) { Task { await applyPermissions() } }
                    Button(appState.tr(.cancel), role: .cancel) { }
            }
            .task {
                await loadProperties()
            }
    }

    private func attemptClose() {
        if hasPendingPermissionChanges {
            showDiscardConfirmation = true
        } else {
            dismiss()
        }
    }

    private var kindText: String {
        detailedProps?.kind ?? (item.isDirectory ? appState.tr(.folder) : item.fileExtension.uppercased())
    }

    private var contentArea: some View {
        ScrollView {
            VStack(spacing: 16) {
                generalSection

                if detailedProps?.dimensions != nil || detailedProps?.duration != nil {
                    Divider()
                    moreInfoSection
                }

                if exifData != nil {
                    Divider()
                    exifSection
                }

                Divider()
                permissionsSection
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }

    private var generalSection: some View {
        DisclosureGroup(isExpanded: $isGeneralExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                if let kind = detailedProps?.kind {
                    propertyRow(label: appState.tr(.kind), value: kind)
                }
                propertyRow(label: appState.tr(.size), value: item.formattedSize)
                propertyRow(label: appState.tr(.location), value: item.url.deletingLastPathComponent().path, wraps: true)
                propertyRow(label: appState.tr(.dateModified), value: item.formattedDate(language: appState.preferences.appLanguage))
            }
            .padding(.top, 8)
        } label: {
            Text(appState.tr(.general)).font(.headline)
        }
    }

    private var moreInfoSection: some View {
        DisclosureGroup(isExpanded: $isMoreInfoExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                if let dims = detailedProps?.dimensions {
                    propertyRow(label: appState.tr(.dimensions), value: dims)
                }
                if let dur = detailedProps?.duration {
                    propertyRow(label: appState.tr(.duration), value: dur)
                }
            }
            .padding(.top, 8)
        } label: {
            Text(appState.tr(.moreInfo)).font(.headline)
        }
    }

    @ViewBuilder private var exifSection: some View {
        if let exif = exifData {
            DisclosureGroup(isExpanded: $isExifExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    if let model = exif.cameraModel {
                        propertyRow(label: appState.tr(.camera), value: model)
                    }
                    if let lens = exif.lensModel {
                        propertyRow(label: appState.tr(.lens), value: lens)
                    }
                    if let iso = exif.iso {
                        propertyRow(label: appState.tr(.exifISO), value: iso)
                    }
                    if let ap = exif.aperture {
                        propertyRow(label: appState.tr(.aperture), value: ap)
                    }
                    if let fl = exif.focalLength {
                        propertyRow(label: appState.tr(.focalLength), value: fl)
                    }
                    if let dt = exif.dateTimeOriginal {
                        propertyRow(label: appState.tr(.dateTaken), value: dt)
                    }
                    if let gps = exif.gpsCoordinates {
                        propertyRow(label: appState.tr(.exifGPS), value: gps)
                    }
                }
                .padding(.top, 8)
            } label: {
                Text(appState.tr(.exifSectionTitle)).font(.headline)
            }
        }
    }

    private var permissionsSection: some View {
        DisclosureGroup(isExpanded: $isPermissionsExpanded) {
            permissionsContent
                .padding(.top, 8)
        } label: {
            Text(appState.tr(.sharingAndPermissions)).font(.headline)
        }
    }

    private var permissionsContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            propertyRow(label: appState.tr(.owner), value: item.ownerName)
            propertyRow(label: appState.tr(.group), value: item.groupName)

            if hasPermissions {
                permissionsEditor
            }
        }
    }

    private var permissionsEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(appState.tr(.permissions) + " (" + permissions.octalString + "):")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
            }

            permissionsRow(title: appState.tr(.owner), read: $permissions.ownerRead, write: $permissions.ownerWrite, execute: $permissions.ownerExecute)
            permissionsRow(title: appState.tr(.group), read: $permissions.groupRead, write: $permissions.groupWrite, execute: $permissions.groupExecute)
            permissionsRow(title: appState.tr(.others), read: $permissions.othersRead, write: $permissions.othersWrite, execute: $permissions.othersExecute)

            if item.isDirectory {
                Toggle(appState.tr(.applyToEnclosedItems), isOn: $applyToEnclosedItems)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                    .accessibilityLabel(appState.tr(.applyToEnclosedItems))
            }

            applyPermissionsButton
        }
    }

    private var applyPermissionsButton: some View {
        HStack(spacing: 8) {
            Button(appState.tr(.applyPermissions)) {
                if applyToEnclosedItems {
                    showRecursivePermissionsConfirmation = true
                } else {
                    Task { await applyPermissions() }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(isApplyingPermissions)
            .accessibilityLabel(appState.tr(.applyPermissions))
            .accessibilityHint(appState.tr(.applyPermissionsHint))

            if isApplyingPermissions {
                ProgressView().controlSize(.small)
            } else if let applyPermissionsResult {
                Text(applyPermissionsResult)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 4)
    }

    private func loadProperties() async {
        detailedProps = await FileMetadataService.shared.fetchProperties(for: item.url)
        exifData = await Task.detached(priority: .userInitiated) {
            ExifMetadataService.extractExif(from: item.url)
        }.value
        let url = item.url
        if let loadedPermissions = await Task.detached(priority: .userInitiated, operation: {
            FilePermissionsService.getPermissions(for: url)
        }).value {
            permissions = loadedPermissions
            lastAppliedPermissions = loadedPermissions
            hasPermissions = true
        }
    }

    private func applyPermissions() async {
        let url = item.url
        let permissionsToApply = permissions
        isApplyingPermissions = true
        applyPermissionsResult = nil
        defer { isApplyingPermissions = false }
        if applyToEnclosedItems {
            let result = await Task.detached(priority: .userInitiated) {
                FilePermissionsService.setPermissionsRecursively(for: url, permissions: permissionsToApply)
            }.value
            if let firstError = result.errors.first {
                ErrorReporter.report(firstError, context: "Applying recursive file permissions")
                appState.showError(firstError.localizedDescription)
            }
            var message = String(format: appState.tr(.permissionsAppliedCount), result.applied)
            if !result.errors.isEmpty {
                message += " · " + String(format: appState.tr(.permissionsApplyFailedCount), result.errors.count)
            }
            applyPermissionsResult = message
        } else {
            do {
                try await Task.detached(priority: .userInitiated) {
                    try FilePermissionsService.setPermissions(for: url, permissions: permissionsToApply)
                }.value
                applyPermissionsResult = String(format: appState.tr(.permissionsAppliedCount), 1)
            } catch {
                ErrorReporter.report(error, context: "Applying file permissions")
                appState.showError(error.localizedDescription)
            }
        }
        if let reloaded = await Task.detached(priority: .userInitiated, operation: {
            FilePermissionsService.getPermissions(for: url)
        }).value {
            permissions = reloaded
            lastAppliedPermissions = reloaded
        }
    }

    private func permissionsRow(title: String, read: Binding<Bool>, write: Binding<Bool>, execute: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Text(title + ":")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .trailing)
            Toggle(appState.tr(.read), isOn: read)
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
                .accessibilityLabel("\(title) \(appState.tr(.read))")
                .accessibilityHint(appState.tr(.permissionToggleHint))
            Toggle(appState.tr(.write), isOn: write)
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
                .accessibilityLabel("\(title) \(appState.tr(.write))")
                .accessibilityHint(appState.tr(.permissionToggleHint))
            Toggle(appState.tr(.execute), isOn: execute)
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
                .accessibilityLabel("\(title) \(appState.tr(.execute))")
                .accessibilityHint(appState.tr(.permissionToggleHint))
            Spacer()
        }
    }

    private func propertyRow(label: String, value: String, wraps: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label + ":")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 12))
                .lineLimit(wraps ? nil : 2)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
                .help(wraps ? value : "")
        }
    }
}
