import Foundation
@testable import Wiles

@MainActor
public struct SmallModelEnumsTests {
    public static func run() {
        testNavigationMode()
        testViewMode()
        testSortOption()
        testAppAppearance()
        testFolderNodeEqualityAndHashing()
        testSidebarItemIdentity()
    }

    private static func testNavigationMode() {
        report("NavigationMode", "POS: CaseIterable has exactly the 2 known cases", result: NavigationMode.allCases.count == 2)
        for mode in NavigationMode.allCases {
            report("NavigationMode", "POS: rawValue round-trips for \(mode)", result: NavigationMode(rawValue: mode.rawValue) == mode)
            report("NavigationMode", "POS: id equals rawValue for \(mode)", result: mode.id == mode.rawValue)
            report("NavigationMode", "POS: shortName is non-empty for \(mode)", result: !mode.shortName.isEmpty)
            report("NavigationMode", "POS: shortName is shorter than the verbose rawValue for \(mode)", result: mode.shortName.count < mode.rawValue.count)
        }
        report("NavigationMode", "NEG: garbage rawValue returns nil", result: NavigationMode(rawValue: "vim mode") == nil)
        report("NavigationMode", "POS: shortName differs between gnome and macOS", result: NavigationMode.gnome.shortName != NavigationMode.macOS.shortName)
    }

    private static func testViewMode() {
        report("ViewMode", "POS: CaseIterable has exactly the 3 known cases", result: ViewMode.allCases.count == 3)
        for mode in ViewMode.allCases {
            report("ViewMode", "POS: rawValue round-trips for \(mode)", result: ViewMode(rawValue: mode.rawValue) == mode)
            report("ViewMode", "POS: id equals rawValue for \(mode)", result: mode.id == mode.rawValue)
        }
        report("ViewMode", "NEG: garbage rawValue returns nil", result: ViewMode(rawValue: "Table") == nil)
        let asSet: Set<ViewMode> = [.grid, .grid, .list]
        report("ViewMode", "POS: Hashable conformance dedups equal cases in a Set", result: asSet.count == 2)
    }

    private static func testSortOption() {
        report("SortOption", "POS: CaseIterable has exactly the 8 known cases", result: SortOption.allCases.count == 8)
        for option in SortOption.allCases {
            report("SortOption", "POS: rawValue round-trips for \(option)", result: SortOption(rawValue: option.rawValue) == option)
            report("SortOption", "POS: id equals rawValue for \(option)", result: option.id == option.rawValue)
        }
        report("SortOption", "NEG: garbage rawValue returns nil", result: SortOption(rawValue: "Random Order") == nil)
        report("SortOption", "NEG: rawValue is case-sensitive (lowercase garbage returns nil)", result: SortOption(rawValue: "name") == nil)
    }

    private static func testAppAppearance() {
        report("AppAppearance", "POS: CaseIterable has exactly the 3 known cases", result: AppAppearance.allCases.count == 3)
        for appearance in AppAppearance.allCases {
            report("AppAppearance", "POS: rawValue round-trips for \(appearance)", result: AppAppearance(rawValue: appearance.rawValue) == appearance)
            report("AppAppearance", "POS: id equals rawValue for \(appearance)", result: appearance.id == appearance.rawValue)
        }
        report("AppAppearance", "NEG: garbage rawValue returns nil", result: AppAppearance(rawValue: "auto") == nil)
        report("AppAppearance", "POS: .system maps to settingsSystemOption l10nKey", result: AppAppearance.system.l10nKey == .appearanceSystemOption)
        report("AppAppearance", "POS: .light maps to appearanceLightOption l10nKey", result: AppAppearance.light.l10nKey == .appearanceLightOption)
        report("AppAppearance", "POS: .dark maps to appearanceDarkOption l10nKey", result: AppAppearance.dark.l10nKey == .appearanceDarkOption)
    }

    private static func testFolderNodeEqualityAndHashing() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }

        let nodeA = FolderNode(id: dir, name: "same", url: dir, children: nil)
        let nodeB = FolderNode(id: dir, name: "same", url: dir, children: nil)
        report("FolderNode", "POS: two nodes with identical id/name/url/children are Equatable-equal", result: nodeA == nodeB)
        report("FolderNode", "POS: equal nodes produce equal hashes", result: nodeA.hashValue == nodeB.hashValue)

        let otherURL = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let nodeC = FolderNode(id: otherURL, name: "same", url: dir, children: nil)
        report("FolderNode", "NEG: differing id makes nodes unequal even if other fields match", result: nodeA != nodeC)

        let child = FolderNode(id: dir.appendingPathComponent("child"), name: "child", url: dir.appendingPathComponent("child"), children: nil)
        let parentWithChild = FolderNode(id: dir, name: "same", url: dir, children: [child])
        report("FolderNode", "NEG: presence of children makes a node unequal to an otherwise-identical childless node", result: nodeA != parentWithChild)

        let parentWithEmptyChildren = FolderNode(id: dir, name: "same", url: dir, children: [])
        report("FolderNode", "NEG: an empty children array is not equal to nil children", result: nodeA != parentWithEmptyChildren)

        let setOfNodes: Set<FolderNode> = [nodeA, nodeB, nodeC]
        report("FolderNode", "POS: Set dedups structurally-equal FolderNode values", result: setOfNodes.count == 2)
    }

    private static func testSidebarItemIdentity() {
        let url = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let itemA = SidebarItem(name: "Downloads", iconName: "folder", url: url)
        let itemB = SidebarItem(name: "Downloads", iconName: "folder", url: url)
        report("SidebarItem", "NEG: two items with identical name/icon/url are NOT equal because id is a freshly-generated UUID", result: itemA != itemB)
        report("SidebarItem", "POS: an item is equal to itself", result: itemA == itemA)
        report("SidebarItem", "POS: id is stable across repeated reads of the same instance", result: itemA.id == itemA.id)
        let setOfItems: Set<SidebarItem> = [itemA, itemB]
        report("SidebarItem", "POS: distinct-id items with equal content are NOT deduped by a Set", result: setOfItems.count == 2)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
