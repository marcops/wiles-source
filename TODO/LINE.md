# Wiles Review — Slice G2: Models + AppState Stores

### Models/AppState/Stores/PreferencesStore.swift
- **[Category: Architecture]** ~35 stored properties each carry a hand-copied `didSet { UserDefaults.standard.set(x, forKey: DefaultsKey.y.rawValue) }`. **Recommendation:** introduce a `@Persisted(.viewMode)` property wrapper keyed off `DefaultsKey`. *(Evaluated: real DRY issue but a refactor across ~35 properties is too large/regression-risky for a single pass — deferred.)*
- **[Category: Architecture]** `smartFolders: [SmartFolder]` lives on `PreferencesStore` even though a dedicated `SmartFolderStore` exists in the same directory. **Recommendation:** move `smartFolders` onto `SmartFolderStore` next to `activeFolderID`. *(Evaluated: moving it breaks View call sites (`SidebarView`, `SmartFoldersSectionView`) reading `preferences.smartFolders` — deferred.)*
- **[Category: Bug]** `isSidebarCollapsed` / `showDirectoryTree` are shared but conceptually per-window (Finder treats sidebar collapse and tree visibility per-window). **Recommendation:** same per-window pattern already applied to `showTerminalDrawer`/`showPreviewSidebar`/`showDiskUsageSidebar`/`sidebarWidth`. *(Evaluated: call site lives in SidebarView.swift, owned by a different pass — deferred.)*
- **[Category: Bug]** `viewMode` is shared but per-folder/per-window in Finder. *(Evaluated: call site lives in AppState+ColumnsAndActions.swift, owned by a different pass — deferred.)*

### Models/AppState/Stores/NavigationStore.swift
- **[Category: Bug]** `currentURL`'s `didSet` writes `DefaultsKey.lastOpenedFolder` from *every* window on *every* navigation against a single shared key. With multiple windows open, "restore last folder" on next launch restores whichever window happened to navigate last, which is effectively arbitrary. **Recommendation:** either write this only from the key window (check `NSApp.keyWindow`), or persist an array of open-window folders and restore per window. *(Evaluated: real, needs window-identity plumbing (a live `NSWindow` check) not available inside this file — deferred.)*
- **[Category: Architecture]** `addToRecents` recognizes two *different* virtual-URL conventions in one expression: `std == AppState.recentsVirtualURL` (a magic `/virtual/recents` file path) and `std.scheme == "wiles"`. **Recommendation:** collapse to one — make `recentsVirtualURL` a `wiles://recents` URL. *(Evaluated: real, but changing `recentsVirtualURL`'s scheme risks breaking path-based breadcrumb/goUp logic elsewhere — deferred, needs careful manual verification.)*

### Models/AppState/Stores/FileSystemStore.swift
- **[Category: Architecture]** `renamingURL` is documented as "suppresses `items` refreshes while set" — but `WindowUIState` already owns `renameItem` plus cancellation methods. Rename state lives in two places kept in sync manually. **Recommendation:** derive the suppression from `WindowUIState.renameItem` directly and delete `renamingURL`. *(Confirmed still real — both flags are actively kept in sync via `onRenameCleared`, but deriving suppression directly requires editing AppState+Operations.swift/AppState+Navigation.swift — deferred.)*

### Models/BoundedFolderNodeCache.swift
- **[Category: Performance]** Eviction is FIFO by *insertion*, and `get` never touches `insertionOrder` — so an actively re-read folder is as likely to be evicted as one visited once an hour ago. **Recommendation:** make it a real LRU, or use `NSCache<NSURL, FolderNodeList>` with `countLimit` (as `DirectoryCacheService`/`ThumbnailService` already do). *(Evaluated: real; a mutating `get` on the subscript would write back through the `@Binding` this type is threaded through in SidebarView.swift on every read, risking re-render storms — deferred.)*
- **[Category: Performance]** Being a `struct` held as `@State`/`@Binding`, every cache write invalidates the entire sidebar body. **Recommendation:** make it a `final class`/`@Observable` service. *(Evaluated: converting to a class alone doesn't fix it — dictionary-keyed writes still invalidate every reader; needs a real per-node store, an app-wide change — deferred.)*

### Models/DirectoryCacheEntry.swift
- **[Category: Performance]** The payload behind `DirectoryCacheService`'s `totalCostLimit = 30 MB` estimates 128 bytes/item, but each cached `FileItem` holds a 512×512 `NSImage` plus tags/dates — the "30 MB" limit doesn't bound anything meaningful. **Recommendation:** exclude icons from the cached payload, or compute a real cost from the icon representations. *(Evaluated: real, but a more "accurate" cost guess risks evicting everything instantly with no profiling data to validate against — deferred.)*

### Models/FileItem.swift
- **[Category: Performance]** `resolveHighResIcon` forces every icon to 512×512 regardless of where it's actually rendered (grid ≈54pt, list smaller). **Recommendation:** size to the largest size actually rendered. *(Evaluated: real; needs new parameters threaded through 7 call sites across multiple files — deferred.)*
- **[Category: Performance]** `init` performs synchronous disk I/O and is called directly from `@MainActor` context-menu code (`SidebarItemContextMenu.swift`, `SharedBackgroundContextMenu.swift`), including for `/Volumes/` entries — right-clicking a sleeping network share can beachball the app. **Recommendation:** make the initializer `nonisolated` and give those two call sites an `async` factory. *(Evaluated: real; SwiftUI `.contextMenu` builders can't easily go async — needs dedicated verification against a real stalled mount — deferred.)*

### Models/ListColumn.swift
- **[Category: Architecture]** `ListColumn` and `SortOption` are the same eight concepts with identical raw values, joined by a hand-written 8-case identity mapping in `FileListHeaderView.swift`. **Recommendation:** collapse into one enum. *(Evaluated: real, but unifying risks breaking persisted `UserDefaults` raw values across FileListHeaderView.swift/ViewMenuCommands.swift — deferred.)*

### Models/SortOption.swift
- **[Category: Architecture]** Duplicate of `ListColumn` — see that file's finding. *(Evaluated: same risk — deferred.)*

# Slice G4 — Header + Sidebar review

### Views/Sidebar/SidebarView.swift
- **[Category: Product-UX]** Favorites cannot be reordered and cannot be created by dragging. In Finder, dragging a folder into the sidebar is *the* primary way to add a favorite. **Recommendation:** add `.onDrag` + `.onMove` on the Favorites branch. *(Evaluated: real feature work with gesture-conflict risk against existing row interactions — deferred.)*

### Views/Sidebar/SidebarRowView.swift
- **[Category: Product-UX]** `rowContextMenu` has no "Open in New Window" — the app already has "Show in Finder" plumbing (now hoisted in) but opening a new window for a sidebar target needs new `WindowGroup(for:)` plumbing in `WilesApp.swift`. *(Evaluated: real, deferred as its own scene-management change.)*

### Views/Sidebar/DirectoryTreeNodeView.swift
- **[Category: Performance]** `isExpanded`/`toggleExpanded` read/mutate the shared `preferences.expandedTreePaths` `Set`, so expanding one node re-renders every `DirectoryTreeNodeView` in the tree. **Recommendation:** move expansion state into a dedicated leaf `@Observable` tree store keyed per node. *(Evaluated: real, requires a per-node observable store — an app-wide architectural change — deferred.)*

### Views/Sidebar/TagsSectionView.swift
- **[Category: Product-UX]** `ForEach(TagColor.allCases, ...)` lists every tag color unconditionally with no counts or filtering to tags in use. **Recommendation:** add a trailing count badge and hide zero-count tags. *(Evaluated: real; accurate counts need a Spotlight query per tag color, a new subsystem — deferred.)*
- **[Category: Product-UX]** No context menu on a tag row — no way to rename/remove/hide. *(Evaluated: "hide" needs a new PreferencesStore.swift field, owned by a different pass; rename/remove-all are heavier new Finder-tag features — deferred.)*

### Views/Modals/AutoOrganizationSheet.swift
- **[Category: Architecture]** `rules` is a `@State` snapshot of `AutoOrganizationService.shared.rules` refreshed by hand from four call sites — a second source of truth for state the service already owns. **Recommendation:** make the sheet read the service's `rules` directly (`@Observable` service). *(Evaluated: real; Observable-macro instrumentation of a computed pass-through property needs verification against real Spotlight/service behavior — deferred.)*

# Slice G3 — Models/AppState/

### Models/AppState/AppState+Operations.swift
- **[Category: Bug]** *Data loss — cut+paste silently overwrites a same-named file with no confirmation, and copy+paste doesn't.* `executePaste` (cut branch) calls `FileSystemService.moveItem`, which on a name collision runs `FileManager.replaceItem` — the destination file is **destroyed and replaced with no prompt**. The copy branch routes through `uniqueDestination` and appends `_1`. The recorded undo can only move the file back, so ⌘Z does **not** restore the pre-paste state. **Recommendation:** detect collisions before the loop and surface a Finder-style "Keep Both / Replace / Skip" decision. *(Evaluated: real, high-severity — root cause is in Services/FileSystemService+Actions.swift (`moveItem`), and the full fix also needs a new confirmation UI in Views — deferred, needs dedicated attention.)*
- **[Category: Bug]** *Irreversible destructive actions have no confirmation while the reversible one does.* `deletePermanentlySelected()` and `shredSelected()` execute immediately with no confirmation gate and record no undo — while the *recoverable* Trash action is the only one that asks. **Recommendation:** give both their own `WindowUIState` confirmation alert. *(Evaluated: real — needs a new WindowUIState.swift property, owned by a different pass — deferred.)*

### Models/AppState/AppState+Archive.swift
- **[Category: Bug]** *Password strength.* `compressSelectedToZIPWithPassword` uses `zip`'s legacy, trivially-breakable ZipCrypto. Passing it via `ps`-visible argv is already mitigated (routed through an env var), but the underlying cipher is still weak. **Recommendation:** switch to a library-based AES-256 zip. *(Evaluated: real, but adding a new dependency for this is a tech/scope decision that needs the user's say — deferred, ask before doing.)*

### Models/AppState/AppState+SmartFolders.swift
- **[Category: Product-UX]** A smart folder has no failure story. `SmartFolderService.shared.executeQuery` takes a success-only closure; if Spotlight is disabled or the saved query is malformed, the user gets an empty list indistinguishable from "genuinely no matches". **Recommendation:** give `executeQuery` a `Result`-shaped completion. *(Evaluated: real; reliably detecting "Spotlight disabled" vs "still running" needs real heuristic design work — deferred.)*

### Models/AppState/AppState+Text.swift
- **[Category: Performance]** `statusText` is an O(n) computed property read directly from a view body — up to three full passes over `fileSystem.items` on every mutation. **Recommendation:** cache the total-files aggregate on `FileSystemStore`, computed once when `items` is assigned. *(Evaluated: real, correct fix needs a cached aggregate on FileSystemStore.swift, owned by a different pass — deferred.)*

### Models/AppState/AppState+Error.swift
- **[Category: Product-UX]** No error has a recovery action. Every failure terminates at a message-only alert with an OK button. **Recommendation:** introduce a small `UserFacingError` type carrying an optional recovery action. *(Evaluated: real; a real Retry feature needs per-call-site semantics design, too broad for a single pass — deferred.)*

### Models/AppState/WindowUIState.swift
- **[Category: Architecture]** `isAnyModalPresented` is a hand-maintained 15-term disjunction that will silently rot — adding a 16th sheet without remembering to extend this list re-opens the keyboard-fallthrough bug the property exists to prevent. **Recommendation:** replace the flat booleans with a single `presentedSheet: SheetKind?` enum. *(Evaluated: real, collapsing requires updating every View call site that sets these booleans (~40 sites) — deferred.)*
- **[Category: Product-UX]** `showSettingsSheet`/`showAboutSheet`/`showHelpSheet`/`showFeedbackSheet` are window-scoped, but conceptually app-scoped — opening Settings in two windows yields two independent, potentially-stale sheets. **Recommendation:** promote these four to app-level presentation. *(Evaluated: real; needs real macOS `Settings`/`Window` scenes and singleton-window management, a genuine windowing-behavior change — deferred.)*

