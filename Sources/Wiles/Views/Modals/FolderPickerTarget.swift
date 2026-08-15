import Foundation

enum FolderPickerTarget: Identifiable {
    case source
    case destination

    var id: Self {
        self
    }
}
