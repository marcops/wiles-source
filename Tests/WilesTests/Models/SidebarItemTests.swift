@testable import Wiles
import Foundation

@MainActor
public struct SidebarItemTests {
    public static func run() {
        let item = SidebarItem(
            name: "Documents",
            iconName: "doc.fill",
            url: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        )
        report("Model/SidebarItem", "POS: SidebarItem name matches 'Documents'", result: item.name == "Documents")
        report("Model/SidebarItem", "POS: SidebarItem iconName matches 'doc.fill'", result: item.iconName == "doc.fill")

        let item2 = SidebarItem(name: "Downloads", iconName: "arrow.down.doc", url: URL(fileURLWithPath: "/tmp"))
        report("Model/SidebarItem", "NEG: Distinct instances have unique UUIDs", result: item.id != item2.id)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
