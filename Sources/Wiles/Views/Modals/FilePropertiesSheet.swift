import SwiftUI

struct FilePropertiesSheet: View {
    let item: FileItem
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(nsImage: item.icon).resizable().frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name).font(.system(size: 16, weight: .bold))
                    Text(item.isDirectory ? "Folder" : item.fileExtension.uppercased() + " File")
                        .font(.system(size: 13)).foregroundColor(.secondary)
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                propertyRow(label: "Location", value: item.url.deletingLastPathComponent().path)
                propertyRow(label: "Size", value: item.formattedSize)
                propertyRow(label: "Modified", value: item.formattedDate)
                propertyRow(label: "Hidden", value: item.isHidden ? "Yes" : "No")
            }
            Spacer()
            HStack {
                Spacer()
                Button("Close") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20).frame(width: 380, height: 280)
    }
    
    private func propertyRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label + ":").font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary).frame(width: 70, alignment: .leading)
            Text(value).font(.system(size: 12)).lineLimit(2).textSelection(.enabled)
        }
    }
}
