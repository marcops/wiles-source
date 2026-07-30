import SwiftUI
import AppKit

struct FilePropertiesSheet: View {
    let item: FileItem
    var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var detailedProps: DetailedFileProperties?
    
    @State private var isGeneralExpanded = true
    @State private var isMoreInfoExpanded = true
    @State private var isPermissionsExpanded = true
    
    var body: some View {
        VStack(spacing: 0) {
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
            
            Divider()
            
            ScrollView {
                VStack(spacing: 16) {
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
                    
                    if detailedProps?.dimensions != nil || detailedProps?.duration != nil {
                        Divider()
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
                    
                    if detailedProps?.ownerName != nil || detailedProps?.groupName != nil || detailedProps?.posixPermissions != nil {
                        Divider()
                        DisclosureGroup(isExpanded: $isPermissionsExpanded) {
                            VStack(alignment: .leading, spacing: 8) {
                                if let owner = detailedProps?.ownerName {
                                    propertyRow(label: appState.tr(.owner), value: owner)
                                }
                                if let group = detailedProps?.groupName {
                                    propertyRow(label: appState.tr(.group), value: group)
                                }
                                if let perms = detailedProps?.posixPermissions {
                                    propertyRow(label: appState.tr(.permissions), value: perms)
                                }
                            }
                            .padding(.top, 8)
                        } label: {
                            Text(appState.tr(.permissions)).font(.headline)
                        }
                    }
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
            
            HStack {
                Spacer()
                Button(appState.tr(.close)) { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 400, height: 500)
        .task {
            detailedProps = await FileMetadataService.shared.fetchProperties(for: item.url)
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
