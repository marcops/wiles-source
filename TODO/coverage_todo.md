# Unit Test Coverage TODO (WilesTests only, non-SwiftUI code)

Generated 2026-08-22 via `swift test --enable-code-coverage --filter WilesTests` +
`xcrun llvm-cov report`, scope limited per `.agents/WILES_RULES.md`'s "Unit Test
Coverage Target: 100% of Non-SwiftUI-View Code" (excludes `Views/`,
`App/Commands/*.swift`, `*SheetView.swift`, other pure SwiftUI `View` structs like
`HttpShareSheet.swift`/`DiskUsageSidebarView.swift`, and the `App` entry point
`App/WilesApp.swift`).

## FINAL RESULT (2026-08-22)

**In-scope coverage: 94.32% lines (326/5737 missed, up from 89.72%), 92.77% functions
(65/899 missed, up from 88.54%), 91.49% regions.** All 1226 unit test assertions pass,
0 failures, 0 hangs, zero build warnings.

3 real test bugs (not production bugs) were found and fixed during consolidation:
inverted guard in `PermissionTests.swift` that was blocking the whole suite on a real
`NSAlert`, a wrong merge-semantics assumption in `FileTaggingServiceTests.swift`, and an
unreliable `FileManager.replaceItemAt` assumption in `ArchiveInspectionServiceTests.swift`.

One suspected (not fixed, flagged for decision) production finding: `AppState+Navigation.
swift`'s `performSearchEverywhereRefresh()` always searches `.userHome` regardless of
`navigation.currentURL` — "search everywhere" is anchored to home, not the actual
filesystem root, and the error-context string names `target.path` as if it were dynamic.

Remaining gaps are all individually documented (inline code comments) as disproportionate
cost per WILES_RULES.md's "100% is a target, not a floor": mostly real macOS system UI
(`NSAlert`/`NSOpenPanel`/System Settings) that would hang an unattended test run, real
Bonjour/Spotlight network timing, and defensive branches with no reachable trigger.
Biggest remaining: `AppState+Trash.swift` (39.69%, `performEmptyTrash` isn't
independently testable without risking the real `~/.Trash`), `NetworkDiscoveryService.
swift` (53.70%, the bulk is `private` and only reachable from a real Bonjour callback),
`PermissionService.swift` (33.33%, real FDA alert), `OpenWithService.swift` (61.54%, real
`NSOpenPanel`).

Work was split into 3 balanced groups (~197 missed lines each) dispatched to 3 parallel agents.

## Group 1 — Status: done

| File | Missed Lines | Notes |
|---|---:|---|
| Models/AppState/AppState+Trash.swift | 80 | lowest-coverage file in scope (38.93%) |
| Features/HttpSharing/LocalHttpServerService.swift | 28 | |
| Models/BoundedFolderNodeCache.swift | 25 | 19.35% line coverage |
| Services/PasteboardService.swift | 20 | |
| Services/FileSystem/FileSystemService+Actions.swift | 12 | |
| Features/DiskSpaceVisualizer/DiskSpaceVisualizerService.swift | 8 | |
| Features/SmartFolders/SmartFolderService.swift | 6 | |
| Constants/AppConstants.swift | 5 | |
| Services/FileSystem/SearchFilterService.swift | 3 | |
| Models/FolderNode.swift | 3 | |
| Models/AppState/AppState+Text.swift | 3 | |
| Services/TemplateRenderingService.swift | 2 | |
| Services/ThumbnailService.swift | 1 | |
| Services/NewFileTemplateService.swift | 1 | |

## Group 2 — Status: done

| File | Missed Lines | Notes |
|---|---:|---|
| Services/FileSystem/FileSystemService.swift | 75 | 70.24% line coverage |
| Services/FileTaggingService.swift | 35 | 0% coverage currently |
| Services/PermissionService.swift | 24 | 33.33% coverage |
| Services/OpenWithService.swift | 20 | |
| Services/SystemAppearanceObserver.swift | 8 | |
| Features/ImageConverter/ImageConverterService.swift | 8 | |
| Services/RealWorkspaceOpener.swift | 6 | |
| Features/FileShredder/FileShredderService.swift | 6 | |
| Services/NetworkServerService.swift | 3 | |
| Services/Bundle+WilesResources.swift | 3 | |
| Models/FileItem.swift | 3 | |
| Features/DuplicateCleaner/DuplicateDetectionService.swift | 3 | |
| Models/WilesError.swift | 2 | |
| Models/SidebarItem.swift | 1 | 0% coverage currently |

## Group 3 — Status: done

| File | Missed Lines | Notes |
|---|---:|---|
| Models/AppState/AppState+Operations.swift | 47 | |
| Models/AppState/AppState+Navigation.swift | 41 | |
| Services/NetworkDiscoveryService.swift | 25 | 53.70% coverage |
| Models/AppState/Stores/PreferencesStore.swift | 21 | |
| Models/AppState/AppState+SmartFolders.swift | 18 | |
| Services/FileMetadataService.swift | 13 | |
| Services/AutoOrganizationRuleStore.swift | 7 | |
| Models/NavigationMode.swift | 6 | |
| Services/SpotlightSearchService.swift | 5 | |
| Services/L10n+Lookup.swift | 3 | |
| Services/AutoOrganizationService.swift | 3 | |
| Models/AppState/Stores/NavigationStore.swift | 3 | |
| Services/UndoRecord.swift | 2 | 0% coverage currently |
| Features/ArchiveInspector/ArchiveInspectionService.swift | 2 | |

## Rules to follow (from `.agents/WILES_RULES.md`)

- Follow the existing test harness pattern exactly: `Tests/WilesTests/.../<Name>Tests.swift`
  (`public struct <Name>Tests { public static func run() [async] { ... } }` using
  `TestReporter.report(...)`) + a standalone `<Name>TestsCase.swift`
  (`final class <Name>TestsCase: XCTestCase` calling `.run()`).
- Branch coverage matters too — every `if`/`guard`/`switch` case, not just lines.
- Zero hardcoded paths — use `NSTemporaryDirectory()`, never `/tmp` literals.
- Strict test isolation — never assume shared singleton/`UserDefaults` state; restore in `defer`.
- If a test reveals the production code doesn't do what it claims, flag it — don't silently
  patch the test to match or "fix" the code without asking.
- Skip a branch/line only when truly disproportionate cost (e.g. unreachable `fatalError`,
  platform branch that can't run in CI) — and say so explicitly.
- Run `swift test --enable-code-coverage --filter WilesTests` to verify before finishing.
