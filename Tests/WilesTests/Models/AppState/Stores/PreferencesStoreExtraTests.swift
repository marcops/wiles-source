import Foundation
@testable import Wiles

@MainActor
public struct PreferencesStoreExtraTests {
    public static func run() {
        testTrailingInspectorCannotRepresentBothInspectors()
        testLoadTrailingInspectorMigratesLegacyBoolKeys()
        testTranslucentLevelSetterUpdatesBothSidebarAndContentLevels()
        testOverlayOpacityIsHalvedInLightAppearance()
        testPerFolderViewModesLoadsSavedDictionaryOrFallsBackToEmpty()
        testLoadEnumIgnoresUnrecognizedSavedRawValue()
        testLoadBoolDistinguishesNeverSavedFromExplicitFalse()
        testTranslucentLevelsLoadSavedPositiveValuesOnInit()
        testListColumnStatesSkipsPersistenceWhileSuppressed()
        testWithColumnStatePersistenceSuppressedIsNestingSafe()
        testSmartFolderCRUDReturnsNilOnSuccessAndAppliesInMemory()
        testKeysToEvictPrefersOldBaselineThenJustAdded()
    }

    /// `keysToEvict` (shared by `expandedTreePaths`/`perFolderViewModes` caps): evicts the
    /// pre-existing baseline first, only dipping into the just-added batch if that isn't enough.
    private static func testKeysToEvictPrefersOldBaselineThenJustAdded() {
        report(
            "Models/PreferencesStore",
            "NEG: keysToEvict returns nothing when under the cap",
            result: ViewPreferences.keysToEvict(current: Set([1, 2, 3]), previous: Set([1, 2]), cap: 5).isEmpty)

        let old: Set = [1, 2, 3, 4]
        let current: Set = [1, 2, 3, 4, 5, 6] // 5,6 just added
        let evicted = Set(ViewPreferences.keysToEvict(current: current, previous: old, cap: 4))
        report(
            "Models/PreferencesStore",
            "POS: keysToEvict trims exactly the overflow, taking from the old baseline first",
            result: evicted.count == 2 && evicted.isSubset(of: old))

        let evictedIntoNew = Set(ViewPreferences.keysToEvict(current: [1, 2, 3, 4, 5], previous: [1], cap: 2))
        report(
            "Models/PreferencesStore",
            "POS: keysToEvict falls back to the just-added batch when the old baseline can't cover the overflow",
            result: evictedIntoNew.count == 3 && evictedIntoNew.contains(1))
    }

    /// The smart-folder CRUD methods now return their persistence error (nil on success) so
    /// `AppState+SmartFolders` can surface a failed rename/removal instead of it being swallowed.
    private static func testSmartFolderCRUDReturnsNilOnSuccessAndAppliesInMemory() {
        let key = DefaultsKey.smartFolders.rawValue
        let prior = UserDefaults.standard.data(forKey: key)
        defer {
            if let prior {
                UserDefaults.standard.set(prior, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        UserDefaults.standard.removeObject(forKey: key)

        let store = PreferencesStore()
        store.smartFolders = []
        let folder = SmartFolder(name: "Docs", searchQuery: "kind:pdf", scopePath: "/tmp")

        report("Models/PreferencesStore", "POS: addSmartFolder returns nil on success", result: store.addSmartFolder(folder) == nil)
        report("Models/PreferencesStore", "POS: addSmartFolder applies the folder in memory", result: store.smartFolders.map(\.id) == [folder.id])
        report("Models/PreferencesStore", "POS: renameSmartFolder returns nil on success", result: store.renameSmartFolder(folder, to: "Papers") == nil)
        report("Models/PreferencesStore", "POS: renameSmartFolder updates the name in memory", result: store.smartFolders.first?.name == "Papers")
        report(
            "Models/PreferencesStore",
            "POS: removeSmartFolder returns nil and empties the list",
            result: store.removeSmartFolder(folder) == nil && store.smartFolders.isEmpty)
    }

    // MARK: - trailingInspector (M22 — replaced the two mutually-exclusive bools)

    /// One `TrailingInspector` enum replaced `showPreviewSidebar`/`showDiskUsageSidebar`, so
    /// "both inspectors on" is now structurally impossible: setting `.preview` then `.diskUsage`
    /// just leaves `.diskUsage`. Snapshots/restores the real `wiles_trailingInspector` key.
    private static func testTrailingInspectorCannotRepresentBothInspectors() {
        let key = DefaultsKey.trailingInspector.rawValue
        let prior = UserDefaults.standard.string(forKey: key)
        defer {
            if let prior {
                UserDefaults.standard.set(prior, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        let store = PreferencesStore()
        store.view.trailingInspector = .preview
        report("Store/PreferencesStore", "POS: trailingInspector holds .preview", result: store.view.trailingInspector == .preview)

        store.view.trailingInspector = .diskUsage
        report(
            "Store/PreferencesStore",
            "POS: setting .diskUsage after .preview leaves only .diskUsage (both-on is unrepresentable)",
            result: store.view.trailingInspector == .diskUsage)

        store.view.trailingInspector = .none
        report("Store/PreferencesStore", "NEG: trailingInspector can be cleared back to .none", result: store.view.trailingInspector == .none)

        store.view.trailingInspector = .diskUsage
        report(
            "Store/PreferencesStore",
            "POS: trailingInspector round-trips through UserDefaults into a fresh store",
            result: PreferencesStore().view.trailingInspector == .diskUsage)
    }

    /// `loadTrailingInspector` migrates a pre-enum install: with only the legacy
    /// `wiles_showPreviewSidebar` / `wiles_showDiskUsageSidebar` bool set (no `wiles_trailingInspector`),
    /// a fresh `PreferencesStore` restores `.preview` / `.diskUsage`; the new key wins over legacy;
    /// neither set → `.none`. Isolates all three raw keys in `defer`.
    private static func testLoadTrailingInspectorMigratesLegacyBoolKeys() {
        let newKey = DefaultsKey.trailingInspector.rawValue
        let legacyPreview = "wiles_showPreviewSidebar"
        let legacyDiskUsage = "wiles_showDiskUsageSidebar"
        let priorNew = UserDefaults.standard.string(forKey: newKey)
        let priorPreview = UserDefaults.standard.object(forKey: legacyPreview)
        let priorDiskUsage = UserDefaults.standard.object(forKey: legacyDiskUsage)
        defer {
            UserDefaults.standard.set(priorNew, forKey: newKey)
            UserDefaults.standard.set(priorPreview, forKey: legacyPreview)
            UserDefaults.standard.set(priorDiskUsage, forKey: legacyDiskUsage)
        }

        UserDefaults.standard.removeObject(forKey: newKey)
        UserDefaults.standard.removeObject(forKey: legacyPreview)
        UserDefaults.standard.removeObject(forKey: legacyDiskUsage)
        report(
            "Store/PreferencesStore",
            "POS: no trailing-inspector keys at all restores .none",
            result: PreferencesStore().view.trailingInspector == .none)

        UserDefaults.standard.set(true, forKey: legacyPreview)
        report(
            "Store/PreferencesStore",
            "POS: legacy wiles_showPreviewSidebar=true (no new key) migrates to .preview",
            result: PreferencesStore().view.trailingInspector == .preview)

        // The migration above writes the new key via `trailingInspector`'s didSet — clear it so the
        // next sub-case genuinely tests the legacy fallback, not the just-migrated value.
        UserDefaults.standard.removeObject(forKey: newKey)
        UserDefaults.standard.removeObject(forKey: legacyPreview)
        UserDefaults.standard.set(true, forKey: legacyDiskUsage)
        report(
            "Store/PreferencesStore",
            "POS: legacy wiles_showDiskUsageSidebar=true (no new key) migrates to .diskUsage",
            result: PreferencesStore().view.trailingInspector == .diskUsage)

        UserDefaults.standard.set(TrailingInspector.none.rawValue, forKey: newKey)
        report(
            "Store/PreferencesStore",
            "POS: an explicit new-key value wins over a conflicting legacy bool",
            result: PreferencesStore().view.trailingInspector == .none)
    }

    // MARK: - translucentLevel computed property

    /// Mutates the real `sidebarTranslucentLevel`/`contentTranslucentLevel` `UserDefaults.standard`
    /// keys via the `translucentLevel` setter, so per rule 17 we snapshot and restore both in `defer`.
    private static func testTranslucentLevelSetterUpdatesBothSidebarAndContentLevels() {
        let sKey = DefaultsKey.sidebarTranslucentLevel.rawValue
        let cKey = DefaultsKey.contentTranslucentLevel.rawValue
        let priorS = UserDefaults.standard.object(forKey: sKey) as? Int
        let priorC = UserDefaults.standard.object(forKey: cKey) as? Int
        defer {
            if let priorS {
                UserDefaults.standard.set(priorS, forKey: sKey)
            } else {
                UserDefaults.standard.removeObject(forKey: sKey)
            }
            if let priorC {
                UserDefaults.standard.set(priorC, forKey: cKey)
            } else {
                UserDefaults.standard.removeObject(forKey: cKey)
            }
        }

        let store = PreferencesStore()
        store.appearance.translucentLevel = 55
        report(
            "Store/PreferencesStore",
            "POS: setting translucentLevel updates both sidebarTranslucentLevel and contentTranslucentLevel",
            result: store.appearance.sidebarTranslucentLevel == 55 && store.appearance.contentTranslucentLevel == 55 && store.appearance.translucentLevel == 55)
    }

    // MARK: - overlay opacity light-mode halving

    /// Mutates the real `sidebarTranslucentLevel`/`contentTranslucentLevel`/`appAppearance`
    /// `UserDefaults.standard` keys, so per rule 17 we snapshot and restore all three in `defer`.
    private static func testOverlayOpacityIsHalvedInLightAppearance() {
        let sKey = DefaultsKey.sidebarTranslucentLevel.rawValue
        let cKey = DefaultsKey.contentTranslucentLevel.rawValue
        let aKey = DefaultsKey.appAppearance.rawValue
        let priorS = UserDefaults.standard.object(forKey: sKey) as? Int
        let priorC = UserDefaults.standard.object(forKey: cKey) as? Int
        let priorA = UserDefaults.standard.string(forKey: aKey)
        defer {
            if let priorS {
                UserDefaults.standard.set(priorS, forKey: sKey)
            } else {
                UserDefaults.standard.removeObject(forKey: sKey)
            }
            if let priorC {
                UserDefaults.standard.set(priorC, forKey: cKey)
            } else {
                UserDefaults.standard.removeObject(forKey: cKey)
            }
            if let priorA {
                UserDefaults.standard.set(priorA, forKey: aKey)
            } else {
                UserDefaults.standard.removeObject(forKey: aKey)
            }
        }

        let store = PreferencesStore()
        store.appearance.sidebarTranslucentLevel = 0
        store.appearance.contentTranslucentLevel = 0

        store.appearance.appAppearance = .dark
        let darkSidebarOpacity = store.appearance.sidebarOverlayOpacity
        let darkContentOpacity = store.appearance.contentOverlayOpacity

        store.appearance.appAppearance = .light
        let lightSidebarOpacity = store.appearance.sidebarOverlayOpacity
        let lightContentOpacity = store.appearance.contentOverlayOpacity

        report(
            "Store/PreferencesStore",
            "POS: sidebarOverlayOpacity is halved in light appearance vs dark",
            result: lightSidebarOpacity == darkSidebarOpacity * 0.5)
        report(
            "Store/PreferencesStore",
            "POS: contentOverlayOpacity is halved in light appearance vs dark",
            result: lightContentOpacity == darkContentOpacity * 0.5)
    }

    // MARK: - perFolderViewModes load fallback

    /// `perFolderViewModes`'s initial value reads a saved dictionary from `UserDefaults` if present,
    /// falling back to `[:]` (the `?? [:]` branch) otherwise. This mutates the real
    /// `UserDefaults.standard` key, so per rule 17 we snapshot and restore in `defer`.
    private static func testPerFolderViewModesLoadsSavedDictionaryOrFallsBackToEmpty() {
        let key = DefaultsKey.perFolderViewModes.rawValue
        let priorValue = UserDefaults.standard.dictionary(forKey: key) as? [String: String]
        defer {
            if let priorValue {
                UserDefaults.standard.set(priorValue, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        UserDefaults.standard.removeObject(forKey: key)
        let emptyStore = PreferencesStore()
        report(
            "Store/PreferencesStore",
            "POS: perFolderViewModes falls back to an empty dictionary when nothing is saved",
            result: emptyStore.view.perFolderViewModes.isEmpty)

        UserDefaults.standard.set(["/tmp/foo": "list"], forKey: key)
        let seededStore = PreferencesStore()
        report(
            "Store/PreferencesStore",
            "POS: perFolderViewModes loads a previously saved dictionary",
            result: seededStore.view.perFolderViewModes["/tmp/foo"] == "list")
    }

    // MARK: - loadEnum with an unrecognized saved raw value

    /// `loadEnum` only assigns when `T(rawValue:)` succeeds — a corrupted/unrecognized saved raw
    /// string must leave the property at its compiled-in default instead of crashing or nil-ing out.
    private static func testLoadEnumIgnoresUnrecognizedSavedRawValue() {
        let key = DefaultsKey.sortOption.rawValue
        let priorValue = UserDefaults.standard.string(forKey: key)
        defer {
            if let priorValue {
                UserDefaults.standard.set(priorValue, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        UserDefaults.standard.set("not-a-real-sort-option", forKey: key)
        let store = PreferencesStore()
        report(
            "Store/PreferencesStore",
            "NEG: an unrecognized saved sortOption raw value is ignored, leaving the default (.name)",
            result: store.view.sortOption == .name)
    }

    // MARK: - loadBool: never-saved vs explicit false

    /// `loadBool` reads `defaults.object(forKey:) != nil` first specifically so an explicitly saved
    /// `false` (which `UserDefaults.bool(forKey:)` can't distinguish from "never saved") is still
    /// applied, while a genuinely-absent key leaves the property's compiled-in default untouched.
    private static func testLoadBoolDistinguishesNeverSavedFromExplicitFalse() {
        let key = DefaultsKey.showFavorites.rawValue
        let priorValue = UserDefaults.standard.object(forKey: key) as? Bool
        defer {
            if let priorValue {
                UserDefaults.standard.set(priorValue, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        UserDefaults.standard.removeObject(forKey: key)
        let neverSavedStore = PreferencesStore()
        report(
            "Store/PreferencesStore",
            "POS: showFavorites keeps its compiled-in default (true) when nothing was ever saved",
            result: neverSavedStore.sidebar.showFavorites)

        UserDefaults.standard.set(false, forKey: key)
        let explicitFalseStore = PreferencesStore()
        report(
            "Store/PreferencesStore",
            "NEG: an explicitly saved false for showFavorites is applied, not skipped as if absent",
            result: !explicitFalseStore.sidebar.showFavorites)
    }

    // MARK: - sidebarTranslucentLevel / contentTranslucentLevel load-from-UserDefaults

    private static func testTranslucentLevelsLoadSavedPositiveValuesOnInit() {
        let sKey = DefaultsKey.sidebarTranslucentLevel.rawValue
        let cKey = DefaultsKey.contentTranslucentLevel.rawValue
        let priorS = UserDefaults.standard.object(forKey: sKey) as? Int
        let priorC = UserDefaults.standard.object(forKey: cKey) as? Int
        defer {
            if let priorS {
                UserDefaults.standard.set(priorS, forKey: sKey)
            } else {
                UserDefaults.standard.removeObject(forKey: sKey)
            }
            if let priorC {
                UserDefaults.standard.set(priorC, forKey: cKey)
            } else {
                UserDefaults.standard.removeObject(forKey: cKey)
            }
        }

        UserDefaults.standard.set(33, forKey: sKey)
        UserDefaults.standard.set(66, forKey: cKey)
        let store = PreferencesStore()
        report(
            "Store/PreferencesStore",
            "POS: a saved positive sidebarTranslucentLevel/contentTranslucentLevel is restored on init",
            result: store.appearance.sidebarTranslucentLevel == 33 && store.appearance.contentTranslucentLevel == 66)
    }

    // MARK: - withColumnStatePersistenceSuppressed (L8)

    /// `listColumnStates`'s `didSet` skips `saveListColumnStates()` entirely while a
    /// `withColumnStatePersistenceSuppressed` body is running (used during bulk column-state
    /// restores and live resize drags that shouldn't each individually re-persist).
    private static func testListColumnStatesSkipsPersistenceWhileSuppressed() {
        let key = DefaultsKey.listColumnStates.rawValue
        let priorData = UserDefaults.standard.data(forKey: key)
        defer {
            if let priorData {
                UserDefaults.standard.set(priorData, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        UserDefaults.standard.removeObject(forKey: key)
        let store = PreferencesStore()
        store.view.withColumnStatePersistenceSuppressed {
            store.view.listColumnStates = []
        }
        report(
            "Store/PreferencesStore",
            "NEG: listColumnStates didSet does not persist while withColumnStatePersistenceSuppressed's body runs",
            result: UserDefaults.standard.data(forKey: key) == nil)

        store.view.listColumnStates = ListColumnState.defaults()
        report(
            "Store/PreferencesStore",
            "POS: listColumnStates didSet persists again once withColumnStatePersistenceSuppressed has returned",
            result: UserDefaults.standard.data(forKey: key) != nil)
    }

    /// `withColumnStatePersistenceSuppressed` restores the *previous* flag value via `defer`, not a
    /// hardcoded `false` — so an inner call returning must not re-enable persistence while an outer
    /// call is still active. Tested behaviorally since the flag itself is `private`.
    private static func testWithColumnStatePersistenceSuppressedIsNestingSafe() {
        let key = DefaultsKey.listColumnStates.rawValue
        let priorData = UserDefaults.standard.data(forKey: key)
        defer {
            if let priorData {
                UserDefaults.standard.set(priorData, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        UserDefaults.standard.removeObject(forKey: key)
        let store = PreferencesStore()

        store.view.withColumnStatePersistenceSuppressed {
            store.view.withColumnStatePersistenceSuppressed {
                store.view.listColumnStates = []
            }
            // Inner call has returned; the outer suppression must still be in force.
            store.view.listColumnStates = Array(ListColumnState.defaults().prefix(1))
            report(
                "Store/PreferencesStore",
                "NEG: an inner withColumnStatePersistenceSuppressed returning does not re-enable persistence while the outer call is still active",
                result: UserDefaults.standard.data(forKey: key) == nil)
        }

        store.view.listColumnStates = ListColumnState.defaults()
        report(
            "Store/PreferencesStore",
            "POS: persistence resumes only after the outermost withColumnStatePersistenceSuppressed returns",
            result: UserDefaults.standard.data(forKey: key) != nil)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
