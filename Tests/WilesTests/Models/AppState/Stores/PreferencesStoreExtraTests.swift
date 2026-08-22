import Foundation
@testable import Wiles

@MainActor
public struct PreferencesStoreExtraTests {
    public static func run() {
        testShowPreviewAndDiskUsageSidebarsAreMutuallyExclusive()
        testTranslucentLevelSetterUpdatesBothSidebarAndContentLevels()
        testOverlayOpacityIsHalvedInLightAppearance()
        testPerFolderViewModesLoadsSavedDictionaryOrFallsBackToEmpty()
        testLoadEnumIgnoresUnrecognizedSavedRawValue()
        testLoadBoolDistinguishesNeverSavedFromExplicitFalse()
        testTranslucentLevelsLoadSavedPositiveValuesOnInit()
        testListColumnStatesSkipsPersistenceWhileSuppressed()
    }

    // MARK: - showPreviewSidebar / showDiskUsageSidebar mutual exclusivity

    /// The two inspector-sidebar toggles occupy the same trailing pane, so turning one on must
    /// force the other off (both `didSet`s, lines ~150-166). This mutates the real
    /// `UserDefaults.standard` keys for both toggles, so per rule 17 we snapshot and restore both
    /// in `defer`.
    private static func testShowPreviewAndDiskUsageSidebarsAreMutuallyExclusive() {
        let previewKey = DefaultsKey.showPreviewSidebar.rawValue
        let diskUsageKey = DefaultsKey.showDiskUsageSidebar.rawValue
        let priorPreview = UserDefaults.standard.object(forKey: previewKey) as? Bool
        let priorDiskUsage = UserDefaults.standard.object(forKey: diskUsageKey) as? Bool
        defer {
            if let priorPreview {
                UserDefaults.standard.set(priorPreview, forKey: previewKey)
            } else {
                UserDefaults.standard.removeObject(forKey: previewKey)
            }
            if let priorDiskUsage {
                UserDefaults.standard.set(priorDiskUsage, forKey: diskUsageKey)
            } else {
                UserDefaults.standard.removeObject(forKey: diskUsageKey)
            }
        }

        let store = PreferencesStore()
        store.showDiskUsageSidebar = false
        store.showPreviewSidebar = false

        store.showPreviewSidebar = true
        report(
            "Store/PreferencesStore",
            "POS: turning on showPreviewSidebar leaves showDiskUsageSidebar off",
            result: store.showPreviewSidebar && !store.showDiskUsageSidebar)

        store.showDiskUsageSidebar = true
        report(
            "Store/PreferencesStore",
            "POS: turning on showDiskUsageSidebar turns off showPreviewSidebar",
            result: store.showDiskUsageSidebar && !store.showPreviewSidebar)

        store.showDiskUsageSidebar = false
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
        store.translucentLevel = 55
        report(
            "Store/PreferencesStore",
            "POS: setting translucentLevel updates both sidebarTranslucentLevel and contentTranslucentLevel",
            result: store.sidebarTranslucentLevel == 55 && store.contentTranslucentLevel == 55 && store.translucentLevel == 55)
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
        store.sidebarTranslucentLevel = 0
        store.contentTranslucentLevel = 0

        store.appAppearance = .dark
        let darkSidebarOpacity = store.sidebarOverlayOpacity
        let darkContentOpacity = store.contentOverlayOpacity

        store.appAppearance = .light
        let lightSidebarOpacity = store.sidebarOverlayOpacity
        let lightContentOpacity = store.contentOverlayOpacity

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
            result: emptyStore.perFolderViewModes.isEmpty)

        UserDefaults.standard.set(["/tmp/foo": "list"], forKey: key)
        let seededStore = PreferencesStore()
        report(
            "Store/PreferencesStore",
            "POS: perFolderViewModes loads a previously saved dictionary",
            result: seededStore.perFolderViewModes["/tmp/foo"] == "list")
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
            result: store.sortOption == .name)
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
            result: neverSavedStore.showFavorites == true)

        UserDefaults.standard.set(false, forKey: key)
        let explicitFalseStore = PreferencesStore()
        report(
            "Store/PreferencesStore",
            "NEG: an explicitly saved false for showFavorites is applied, not skipped as if absent",
            result: explicitFalseStore.showFavorites == false)
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
            result: store.sidebarTranslucentLevel == 33 && store.contentTranslucentLevel == 66)
    }

    // MARK: - listColumnStates persistence suppression flag

    /// `listColumnStates`'s `didSet` skips `saveListColumnStates()` entirely while
    /// `suppressColumnStatePersistence` is true (used during bulk column-state restores that
    /// shouldn't each individually re-persist).
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
        store.suppressColumnStatePersistence = true
        store.listColumnStates = []
        report(
            "Store/PreferencesStore",
            "NEG: listColumnStates didSet does not persist while suppressColumnStatePersistence is true",
            result: UserDefaults.standard.data(forKey: key) == nil)

        store.suppressColumnStatePersistence = false
        store.listColumnStates = ListColumnState.defaults()
        report(
            "Store/PreferencesStore",
            "POS: listColumnStates didSet persists once suppressColumnStatePersistence is false again",
            result: UserDefaults.standard.data(forKey: key) != nil)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
