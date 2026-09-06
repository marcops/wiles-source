import Foundation

extension Screenshots {
    /// One entry per FEATURES.md feature, in the doc's order. `stage` leaves the app in the state
    /// to photograph; `cleanup` returns it to a neutral state for the next shot.
    func shots() -> [Shot] {
        [
            Shot(slug: "grid-list", stage: {
                driver.tap(AXMatch(identifier: "View Mode"), "view mode")
                Timing.pause(Timing.settle)
                driver.tap(AXMatch(identifier: "ViewModeGrid"), "grid")
            }, cleanup: {
                driver.tap(AXMatch(identifier: "View Mode"), "view mode")
                Timing.pause(Timing.settle)
                driver.tap(AXMatch(identifier: "ViewModeList"), "list")
            }),

            Shot(slug: "directory-tree", stage: {
                expandSection("Section_DIRECTORY_TREE")
            }, cleanup: {
                collapseSection("Section_DIRECTORY_TREE")
            }),

            Shot(slug: "favorites-places", stage: {}, cleanup: {}),

            Shot(slug: "smart-folders", stage: {
                activateSearch(query: "uitest")
                driver.tap(AXMatch(textContains: "save as smart folder"), "save smart folder", timeout: 4)
            }, cleanup: {
                driver.dismissSheet()
                deactivateSearch()
            }),

            Shot(slug: "tags", stage: {
                if driver.find(AXMatch(identifier: "Section_TAGS"), timeout: 1) == nil {
                    driver.menuPick("View", path: ["Sidebar", "Show Tags"], "show tags")
                }
            }, cleanup: {}),

            Shot(slug: "search", stage: {
                activateSearch(query: "uitest")
            }, cleanup: {
                deactivateSearch()
            }),

            Shot(slug: "batch-rename", stage: {
                driver.clickRow(workspaceAlpha)
                driver.clickRow(workspaceBeta, modifiers: .command)
                Timing.pause(Timing.brief)
                driver.openContextItem(onFileRow: workspaceBeta, containing: "rename", "rename")
            }, cleanup: { driver.dismissSheet() }),

            Shot(slug: "image-converter", stage: {
                driver.openContextItem(onFileRow: workspaceImage, containing: "quick convert", "convert")
            }, cleanup: { driver.dismissSheet() }),

            Shot(slug: "compress-zip", stage: {
                driver.openContextItem(onFileRow: workspaceAlpha, containing: "compress with password", "compress pw")
            }, cleanup: { driver.dismissSheet() }),

            Shot(slug: "archive-inspector", stage: {
                driver.openContextItem(onFileRow: workspaceZip, containing: "inspect archive", "inspect")
            }, cleanup: { driver.dismissSheet() }),

            Shot(slug: "duplicate-finder", stage: {
                driver.menuPick("Tools", itemContains: "Find Duplicate Files", "duplicates")
            }, cleanup: { driver.dismissSheet() }),

            Shot(slug: "disk-usage", stage: {
                driver.menuPick("View", itemContains: "Show Disk Usage", "disk usage")
            }, cleanup: {
                driver.menuPick("View", itemContains: "Hide Disk Usage", "hide disk usage")
            }),

            Shot(slug: "terminal", stage: {
                driver.menuPick("View", itemContains: "Show Terminal", "terminal")
            }, cleanup: {
                driver.menuPick("View", itemContains: "Hide Terminal", "hide terminal")
            }),

            Shot(slug: "http-sharing", stage: {
                driver.openContextItem(onFileRow: workspaceSub, containing: "share folder over wi-fi", "http share")
            }, cleanup: { driver.dismissSheet() }),

            Shot(slug: "auto-organization", stage: {
                driver.menuPick("Tools", itemContains: "Auto-Organization", "auto-org")
            }, cleanup: { driver.dismissSheet() }),

            Shot(slug: "connect-server", stage: {
                driver.menuPick("Go", itemContains: "Connect to Server", "connect")
            }, cleanup: { driver.dismissSheet() }),

            Shot(slug: "symlinks", stage: {
                driver.openContextItem(onFileRow: workspaceAlpha, containing: "create symlink", "symlink")
            }, cleanup: { driver.dismissSheet() }),

            Shot(slug: "file-properties", stage: {
                driver.clickRow(workspaceAlpha)
                Timing.pause(Timing.brief)
                driver.menuPick("File", itemContains: "Properties", "properties")
            }, cleanup: { driver.dismissSheet() }),

            Shot(slug: "undo-redo", stage: {
                driver.clickRow(workspaceAlpha)
            }, cleanup: {}),

            Shot(slug: "appearance-settings", stage: {
                driver.openSettings(tab: "Appearance")
            }, cleanup: { driver.dismissSheet() }),
        ]
    }

    // MARK: - Shot helpers

    private var workspaceAlpha: String { workspace.alphaFile }
    private var workspaceBeta: String { workspace.betaFile }
    private var workspaceImage: String { workspace.imageFile }
    private var workspaceZip: String { workspace.zipFile }
    private var workspaceSub: String { workspace.subFolder }

    private func expandSection(_ identifier: String) {
        guard let section = driver.find(AXMatch(identifier: identifier), timeout: 3) else { return }
        if (section.stringValue ?? "").lowercased().contains("expand") {
            driver.tapElement(section)
            Timing.pause(Timing.animation)
        }
    }

    private func collapseSection(_ identifier: String) {
        guard let section = driver.find(AXMatch(identifier: identifier), timeout: 3) else { return }
        if (section.stringValue ?? "").lowercased().contains("collapse") {
            driver.tapElement(section)
            Timing.pause(Timing.animation)
        }
    }

    private func activateSearch(query: String) {
        if driver.find(AXMatch(identifier: "SearchTextField"), timeout: 1) == nil {
            driver.tap(AXMatch(identifier: "magnifyingglass"), "search", timeout: 3)
            Timing.pause(Timing.settle)
        }
        if let field = driver.find(AXMatch(identifier: "SearchTextField"), timeout: 4) {
            driver.tapElement(field)
            Timing.pause(Timing.brief)
            driver.type(query)
            Timing.pause(Timing.animation)
        }
    }

    private func deactivateSearch() {
        driver.tap(AXMatch(identifier: "magnifyingglass"), "search close", timeout: 3)
        Timing.pause(Timing.settle)
    }
}
