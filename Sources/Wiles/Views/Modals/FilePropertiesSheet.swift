import AppKit
import GitBeacon
import SwiftUI

struct FilePropertiesSheet: View {
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
    @State private var hasPermissions = false
    @State private var exifData: ExifMetadata?

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            contentArea
            Divider()
            footerView
        }
        .frame(width: 400, height: 500)
        .task {
            await loadProperties()
        }
    }

    private var headerView: some View {
        HStack(spacing: 16) {
            Image(nsImage: item.icon).resizable().frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name).font(.title2).bold().lineLimit(2)
                Text(detailedProps?.kind ?? (item.isDirectory ? appState.tr(.folder) : item.fileExtension.uppercased()))
                    .font(.subheadline).foregroundColor(.secondary)
                Text(item.formattedSize).font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
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
        .background(Color(NSColor.windowBackgroundColor))
        .contentShape(Rectangle())
    }

    private var footerView: some View {
        HStack {
            Spacer()
            Button(appState.tr(.close)) { dismiss() }.keyboardShortcut(.defaultAction)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var generalSection: some View {
        DisclosureGroup(isExpanded: $isGeneralExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                if let kind = detailedProps?.kind {
                    propertyRow(label: appState.tr(.kind), value: kind)
                }
                propertyRow(label: appState.tr(.size), value: item.formattedSize)
                propertyRow(label: appState.tr(.location), value: item.url.deletingLastPathComponent().path)
                propertyRow(label: appState.tr(.dateModified), value: item.formattedDate)
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
                        propertyRow(label: "ISO", value: iso)
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
                        propertyRow(label: "GPS", value: gps)
                    }
                }
                .padding(.top, 8)
            } label: {
                Text("EXIF").font(.headline)
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

            Button(appState.tr(.applyPermissions)) {
                do {
                    try FilePermissionsService.setPermissions(for: item.url, permissions: permissions)
                } catch {
                    ErrorReporter.report(error, context: "Applying file permissions")
                    appState.showError(error.localizedDescription)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .padding(.top, 4)
        }
    }

    private func loadProperties() async {
        detailedProps = await FileMetadataService.shared.fetchProperties(for: item.url)
        exifData = await Task.detached(priority: .userInitiated) {
            ExifMetadataService.extractExif(from: item.url)
        }.value
        if let loadedPermissions = FilePermissionsService.getPermissions(for: item.url) {
            permissions = loadedPermissions
            hasPermissions = true
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
            Toggle(appState.tr(.write), isOn: write)
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
            Toggle(appState.tr(.execute), isOn: execute)
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
            Spacer()
        }
    }

    private func propertyRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label + ":")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .trailing)
            Text(value)
                .font(.system(size: 12))
                .lineLimit(2)
                .textSelection(.enabled)
            Spacer()
        }
    }
}
