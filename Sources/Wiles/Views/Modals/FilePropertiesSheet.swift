import SwiftUI

struct FilePropertiesSheet: View {
    let item: FileItem
    var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(nsImage: item.icon).resizable().frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name).font(.system(size: 16, weight: .bold))
                    Text(item.isDirectory ? appState.tr(.folder) : item.fileExtension.uppercased())
                        .font(.system(size: 13)).foregroundColor(.secondary)
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                propertyRow(label: appState.tr(.location), value: item.url.deletingLastPathComponent().path)
                propertyRow(label: appState.tr(.size), value: item.formattedSize)
                propertyRow(label: appState.tr(.dateModified), value: item.formattedDate)
                propertyRow(label: appState.tr(.hidden), value: item.isHidden ? appState.tr(.yes) : appState.tr(.no))
            }
            Spacer()
            HStack {
                Spacer()
                Button(appState.tr(.close)) { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20).frame(width: 380, height: 280)
    }
    
    private func propertyRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label + ":").font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary).frame(width: 80, alignment: .leading)
            Text(value).font(.system(size: 12)).lineLimit(2).textSelection(.enabled)
        }
    }
}
