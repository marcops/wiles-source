import XCTest
@testable import Wiles

/// `SidebarPlacesBuilder` — the pure list builders extracted from `SidebarView` so the sidebar
/// can cache Favorites / Places / Network & Cloud in `@State` instead of rebuilding them on
/// every `body` pass (L88). Names are checked against `L10n.string(_:lang:)` for the expected
/// key so a mis-wired slot is caught; URLs / icons / order are checked directly.
@MainActor
final class SidebarPlacesBuilderTests: XCTestCase {
    private let lang: AppLanguage = .english

    func testDevicesHasFiveFixedEntriesInOrder() {
        let items = SidebarPlacesBuilder.devices(lang: lang)
        XCTAssertEqual(items.map(\.name), [
            L10n.string(.applications, lang: lang),
            L10n.string(.airDrop, lang: lang),
            L10n.string(.iCloudDrive, lang: lang),
            L10n.string(.macintoshHDName, lang: lang),
            L10n.string(.sidebarTrash, lang: lang)
        ])
        XCTAssertEqual(items[0].url, URL(fileURLWithPath: "/Applications"))
        XCTAssertEqual(items[1].url, SidebarItem.airDropURL)
        XCTAssertEqual(items[3].url, URL(fileURLWithPath: "/"))
        XCTAssertEqual(items[0].iconName, "square.grid.3x3.fill")
    }

    func testNetworkAndCloudWithNoSharesIsJustTheNetworkRoot() {
        let items = SidebarPlacesBuilder.networkAndCloud(lang: lang, discoveredShares: [])
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].name, L10n.string(.networkVolumeName, lang: lang))
        XCTAssertEqual(items[0].url, URL(fileURLWithPath: "/Network"))
    }

    func testNetworkAndCloudAppendsDiscoveredSharesAfterRoot() throws {
        let share = try NetworkShare(name: "NAS", url: XCTUnwrap(URL(string: "smb://nas.local")))
        let items = SidebarPlacesBuilder.networkAndCloud(lang: lang, discoveredShares: [share])
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[1].name, "NAS")
        XCTAssertEqual(items[1].url, share.url)
        XCTAssertEqual(items[1].iconName, "network")
    }

    func testItemForRecentsVirtualURLUsesRecentsKeyAndClockIcon() {
        let item = SidebarPlacesBuilder.item(for: AppState.recentsVirtualURL, lang: lang)
        XCTAssertEqual(item.name, L10n.string(.recents, lang: lang))
        XCTAssertEqual(item.iconName, "clock.fill")
    }

    func testItemForWellKnownHomePathUsesHomeKeyAndHouseIcon() {
        let item = SidebarPlacesBuilder.item(for: URL.userHome, lang: lang)
        XCTAssertEqual(item.name, L10n.string(.home, lang: lang))
        XCTAssertEqual(item.iconName, "house.fill")
    }

    func testItemForUnknownPathFallsBackToLastComponentAndFolderIcon() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("SidebarPlaces-\(UUID().uuidString)")
        let item = SidebarPlacesBuilder.item(for: dir, lang: lang)
        XCTAssertEqual(item.name, dir.lastPathComponent)
        XCTAssertEqual(item.iconName, "folder.fill")
    }

    func testFavoritesMapsEveryURLThroughItem() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Fav-\(UUID().uuidString)")
        let items = SidebarPlacesBuilder.favorites(urls: [URL.userHome, dir], lang: lang)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].name, L10n.string(.home, lang: lang))
        XCTAssertEqual(items[1].name, dir.lastPathComponent)
    }
}
