import Foundation

extension PlanWalkthrough {
    // MARK: - Modals

    func featSettingsTabs() {
        reporter.beginFeature("Settings — every tab switches")
        let tabProbe: [(String, [String])] = [
            ("General", ["language", "behaviou", "confirmation"]),
            ("Shortcuts", ["windows", "custom", "mac"]),
            ("Appearance", ["theme", "translucen", "system", "%", "light"]),
            ("Sidebar", ["show tags", "show recents", "show favorites", "directory tree"]),
            ("Advanced", ["compact", "view", "density"]),
        ]
        for (index, probe) in tabProbe.enumerated() {
            guard driver.openSettings(tab: probe.0) else { continue }
            Timing.pause(Timing.animation)
            var hit = false
            for _ in 0 ..< 3 where !hit {
                hit = probe.1.contains { frag in
                    driver.sheet()?.firstDescendant(where: AXMatch(textContains: frag), maxDepth: 28) != nil
                }
                if !hit { Timing.pause(Timing.settle) }
            }
            reporter.check(hit, "Settings ▸ \(probe.0) shows its own content")
            if index == tabProbe.count - 1 { driver.dismissSheet() }
        }
    }

    func featHelpSheet() {
        reporter.beginFeature("Help sheet (⌘?)")
        guard driver.menuPick("Help", itemContains: "Help", "Help ▸ Help") else { return }
        reporter.check(driver.waitForSheet(), "Help sheet opened")
        reporter.check(driver.dismissSheet(), "Help sheet dismissed")
    }

    func featShortcutsHUD() {
        reporter.beginFeature("Shortcuts HUD")
        guard driver.menuPick("Help", itemContains: "Shortcuts", "Help ▸ Shortcuts") else { return }
        let shown = driver.waitForSheet()
            || driver.find(AXMatch(textContains: "shortcuts"), timeout: 3) != nil
        reporter.check(shown, "Shortcuts overlay opened")
        driver.key(Keyboard.escape)
        Timing.pause(Timing.settle)
        driver.dismissSheet()
    }

    func featAboutSheet() {
        reporter.beginFeature("About sheet")
        guard driver.menuPick("Wiles", itemContains: "About Wiles", "Wiles ▸ About Wiles") else { return }
        reporter.check(driver.waitForSheet(), "About sheet opened")
        reporter.check(driver.dismissSheet(), "About sheet dismissed")
    }

    func featFeedbackSheet() {
        reporter.beginFeature("Feedback sheet")
        guard driver.menuPick("Help", itemContains: "Send Feedback", "Help ▸ Send Feedback") else { return }
        reporter.check(driver.waitForSheet(), "Feedback sheet opened")
        reporter.check(driver.dismissSheet(), "Feedback sheet dismissed")
    }
}

extension Walkthrough {
    // MARK: - Appearance Settings

    func featAppearanceSettings() {
        reporter.beginFeature("Appearance Settings")
        driver.navigateToWorkspace()
        guard driver.openSettings(tab: "Appearance") else { return }
        // Switching to a tab swaps its content in — under load that can lag behind the tab click
        // itself, so poll rather than check once immediately.
        var hasAllThemeOptions = false
        let themeOptionsDeadline = Date().addingTimeInterval(4)
        repeat {
            hasAllThemeOptions = ["System", "Light", "Dark"].allSatisfy { option in
                driver.sheet()?.firstDescendant(where: AXMatch(textContains: option)) != nil
            }
            if !hasAllThemeOptions { Timing.pause(Timing.poll) }
        } while !hasAllThemeOptions && Date() < themeOptionsDeadline
        reporter.check(hasAllThemeOptions, "Appearance tab offers Light / Dark / System theme options")

        let switched = driver.selectThemeOption("Dark")
        reporter.check(switched, "selected the 'Dark' theme option")
        Timing.pause(Timing.animation)
        reporter.check(driver.dismissSheet(), "Settings dismissed after choosing Dark")

        Timing.pause(Timing.settle)
        let persisted = driver.process.readDefault("wiles_appAppearance") ?? ""
        reporter.check(
            persisted.contains("Dark"),
            "'Dark' theme persisted to preferences (wiles_appAppearance = '\(persisted)')")

        guard driver.openSettings(tab: "Appearance") else { return }
        driver.selectThemeOption("System")
        driver.dismissSheet()

        reporter.check(
            driver.menuHasItem("View", path: ["Appearance"], containing: "Director View"),
            "View ▸ Appearance ▸ Director View reset is available")
        reporter.check(
            driver.menuHasItem("View", path: ["Appearance"], containing: "Default"),
            "View ▸ Appearance ▸ Default reset is available")
    }

    // MARK: - Shortcuts

    func featShortcuts() {
        reporter.beginFeature("Shortcuts settings — Custom remap")
        driver.navigateToWorkspace()
        guard driver.openSettings(tab: "Shortcuts") else { return }

        var hasAllModes = false
        let modesDeadline = Date().addingTimeInterval(4)
        repeat {
            hasAllModes = ["Windows", "Custom"].allSatisfy { option in
                driver.sheet()?.firstDescendant(where: AXMatch(textContains: option)) != nil
            }
            if !hasAllModes { Timing.pause(Timing.poll) }
        } while !hasAllModes && Date() < modesDeadline
        reporter.check(hasAllModes, "Shortcuts tab offers Windows / Mac / Custom modes")

        let switchedToCustom = driver.selectPickerOption("Custom", popupIndex: 0)
        reporter.check(switchedToCustom, "selected the 'Custom' shortcut mode")
        Timing.pause(Timing.settle)

        // "Undo" is the 2nd row in `ShortcutRegistry.editableCommands` order — on-screen without
        // scrolling the Form, unlike a row further down the ~35-row Custom list (its AX frame is
        // reported in the list's full unclipped layout coordinates, not the visible viewport, so a
        // synthetic click at a scrolled-off row's frame silently misses everything).
        let rowElement = driver.sheet()?.firstDescendant(where: AXMatch(textContains: "Undo"), maxDepth: 28)
        reporter.check(rowElement != nil, "Custom mode shows the full editable shortcut list (e.g. 'Undo')")

        let rowTapped = rowElement.map { driver.tapElement($0) } ?? false
        reporter.check(rowTapped, "tapped the 'Undo' row to start capturing a new key")
        Timing.pause(Timing.settle)
        let capturing = driver.sheet()?.firstDescendant(where: AXMatch(textContains: "Press a key"), maxDepth: 28) != nil
        reporter.check(capturing, "row entered capture mode ('Press a key combination…')")
        driver.chord("9", .command)
        Timing.pause(Timing.settle)
        let remapped = driver.sheet()?.firstDescendant(where: AXMatch(textContains: "⌘ 9"), maxDepth: 28) != nil
        if !remapped {
            let dump = driver.sheet()?.allDescendants(where: AXMatch(textContains: "Undo"), maxDepth: 28)
                .map { "\($0.role) title='\($0.title)' value='\($0.stringValue ?? "")'" }
                .joined(separator: " | ") ?? "no sheet"
            reporter.fail("remap diagnostic — Undo-related elements now: \(dump)")
        }
        reporter.check(remapped, "'Undo' now shows the newly captured ⌘9 combo")

        driver.dismissSheet()

        // Restore the Windows preset so later steps (and any other run) see default bindings —
        // this also proves selecting a preset bulk-overwrites the Custom edit just made.
        if driver.openSettings(tab: "Shortcuts") {
            driver.selectPickerOption("Windows", popupIndex: 0)
            driver.dismissSheet()
        }
        driver.navigateToWorkspace()
    }
}
