import Foundation

/// Pure builders for the sidebar's "Favorites" / "Places" / "Network & Cloud" item lists.
/// Split out of `SidebarView` so the view can cache the results in `@State` and rebuild them
/// only when favorites, discovered network shares, or the app language actually change —
/// instead of reconstructing every list on every `body` pass (each `SidebarItem`'s identity and
/// equality normalize its URL via `standardizedFileURL`).
enum SidebarPlacesBuilder {
    /// Path -> (localization key, icon) for well-known folders, built once since `URL.userHome`
    /// is fixed for the process.
    static let wellKnownPaths: [String: (key: L10n.Key, icon: String)] = {
        let home = URL.userHome.standardizedFileURL
        return [
            home.path: (.home, "house.fill"),
            home.appendingPathComponent("Desktop").path: (.desktop, "desktopcomputer"),
            home.appendingPathComponent("Documents").path: (.sidebarDocuments, "doc.fill"),
            home.appendingPathComponent("Downloads").path: (.downloads, "arrow.down.circle.fill"),
            "/Applications": (.applications, "square.grid.3x3.fill"),
            home.appendingPathComponent("Music").path: (.music, "music.note"),
            home.appendingPathComponent("Pictures").path: (.pictures, "photo.fill"),
            home.appendingPathComponent("Movies").path: (.movies, "film.fill"),
            URL.userTrash.standardizedFileURL.path: (.sidebarTrash, "trash.fill"),
            "/": (.macintoshHDName, "internaldrive.fill")
        ]
    }()

    static func favorites(urls: [URL], lang: AppLanguage) -> [SidebarItem] {
        urls.map { item(for: $0, lang: lang) }
    }

    /// The Recents virtual URL and well-known folders get their localized name + icon; every
    /// other favorite falls back to its last path component.
    static func item(for url: URL, lang: AppLanguage) -> SidebarItem {
        let std = url.standardizedFileURL
        if std == AppState.recentsVirtualURL.standardizedFileURL {
            return SidebarItem(name: L10n.string(.recents, lang: lang), iconName: "clock.fill", url: std)
        }
        if let entry = wellKnownPaths[std.path] {
            return SidebarItem(name: L10n.string(entry.key, lang: lang), iconName: entry.icon, url: std)
        }
        let name = std.lastPathComponent.isEmpty ? "/" : std.lastPathComponent
        return SidebarItem(name: name, iconName: "folder.fill", url: std)
    }

    static func devices(lang: AppLanguage) -> [SidebarItem] {
        let cloudDocs = URL.userHome.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        return [
            SidebarItem(name: L10n.string(.applications, lang: lang), iconName: "square.grid.3x3.fill", url: URL(fileURLWithPath: "/Applications")),
            SidebarItem(name: L10n.string(.airDrop, lang: lang), iconName: "dot.radiowaves.left.and.right", url: SidebarItem.airDropURL),
            SidebarItem(name: L10n.string(.iCloudDrive, lang: lang), iconName: "icloud.fill", url: cloudDocs),
            SidebarItem(name: L10n.string(.macintoshHDName, lang: lang), iconName: "internaldrive.fill", url: URL(fileURLWithPath: "/")),
            SidebarItem(name: L10n.string(.sidebarTrash, lang: lang), iconName: "trash.fill", url: URL.userTrash)
        ]
    }

    static func networkAndCloud(lang: AppLanguage, discoveredShares: [NetworkShare]) -> [SidebarItem] {
        var list = [SidebarItem(name: L10n.string(.networkVolumeName, lang: lang), iconName: "network", url: URL(fileURLWithPath: "/Network"))]
        list.append(contentsOf: discoveredShares.map { SidebarItem(name: $0.name, iconName: "network", url: $0.url) })
        return list
    }
}
