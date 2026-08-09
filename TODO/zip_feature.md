# Feature: Browse .zip archives like a folder

**Status: paused, not started — pure scoping/assessment done on 2026-08-08.
Implement another day.** Everything needed to resume the discussion from scratch is
below: the goal, both options considered with their tradeoffs, the architecture facts
already gathered (so no need to re-explore the codebase), and the recommendation. Once
implementation starts, also remove the "Inspect Archive" context-menu entry
(`ArchiveInspectionSheetView` / the `ArchiveService.isArchive` context-menu item in
`SharedViewHelpers.swift`) since this feature replaces it.

## Goal
Double-clicking a `.zip` file should open it in-place the same way a real folder does
(reusing whichever view mode is active — Grid/List/Column) and let the user navigate
inside it normally. Double-clicking a file *inside* that zip should extract it to a
temporary location and open it (like macOS does when peeking inside a `.app` bundle).

Once this lands, the existing "Inspect Archive" context-menu sheet
(`ArchiveInspectionSheetView`) becomes redundant and should be removed — this feature
absorbs it.

## Two implementation approaches considered

### Option A — Extract to a temp folder, then navigate there (recommended)
On double-click of a `.zip`, extract the whole archive to a temp folder (reusing
`ArchiveService.extractArchive`, already exists) and call `appState.navigateTo()` on
that temp folder — same as opening any real folder.

**Why it's cheap:** because it becomes a real folder on disk, every existing subsystem
(Grid/List/Column views, `FileItem`, FSEvents `DirectoryMonitor`, drag & drop,
permissions, Disk Space Visualizer, Duplicate Cleaner, Smart Folders, terminal, new
file/folder, etc.) works completely unmodified. Zero model/view changes needed.

**Tradeoffs:**
- Delay before content shows, proportional to archive size (extraction happens
  up front instead of on demand).
- Extra disk usage for the temp copy.
- Edits/renames/deletes inside the browsed zip only affect the extracted temp copy,
  not the original `.zip` — not a true read/write view into the archive.
- Need a temp-folder cleanup policy (on app quit? on navigating away? never?) — undecided.

### Option B — True virtual browsing, no upfront extraction
List entries directly from the zip's central directory (already built and working:
`ZIPCentralDirectoryReader` / `ArchiveInspectionService.listEntries`) and only extract
a single file (`ArchiveInspectionService.extractSingleEntry`, already exists) when the
user double-clicks it inside the virtual listing. Nothing is extracted until it's opened.

**What's already solved** (discovered while scoping this): the "read zip contents
without extracting everything" engine already exists and works — this used to be
the part I assumed was the expensive part of Option B; it isn't anymore.

**What's actually left to build:**
1. **Views only render `FileItem`.** `FileGridView` / `FileListView` / `FileColumnView`
   are hardcoded to a `FileItem` model, built from `URL.resourceValues` of a real file
   on disk (size, dates, icon, tags, owner/group). `ArchiveInspectionService` produces
   a much lighter `ArchiveEntryItem` (path/isDirectory/name only). The views would need
   to accept either type (protocol/generic) — this is the real remaining work, and it's
   UI-layer, not zip-parsing.
2. **Missing metadata has to be synthesized or omitted.** Size/date can be read from
   the zip central directory (cheap, bytes already available). Icon, tags, real Unix
   permissions/owner have no zip equivalent and would need mocked/omitted rendering
   paths in the views.
3. **~20 files assume `navigation.currentURL` is a real, on-disk, FSEvents-watchable
   path** and would need an explicit "not applicable inside a virtual zip" guard,
   mirroring the existing `recentsVirtualURL` special-case pattern (today only handled
   in `AppState+Navigation.swift` / `FileSystemStore` / `FileSystemService`, not
   generalized). Affected areas: Disk Space Visualizer, Duplicate Cleaner, Smart
   Folders (save current dir as bookmark), integrated Terminal (`cd`'s to a real path),
   New File/Folder sheets, PathBar breadcrumb navigation, `DirectoryMonitor`/FSEvents.

**Tradeoffs:** more work than Option A, but the gap shrank once we confirmed the
listing/extraction engine (`ZIPCentralDirectoryReader` + `extractSingleEntry`) already
exists — remaining cost is UI adaptation + defensive guards, not a new zip-reading engine.

## Architecture facts gathered (for whoever picks this up)

- `AppState.navigation.currentURL` is a plain `URL`, used as a real filesystem path
  everywhere (`.path`, `FileManager.default.fileExists`, etc.) — see
  `AppState+Navigation.swift`.
- `navigateTo` (`AppState+Navigation.swift:10-35`) classifies the target via
  `FileManager.default.fileExists(atPath:isDirectory:)`. Non-directories go straight
  to `NSWorkspace.shared.open(url)` in `completeNavigation` (line 52) — a `.zip` would
  need an explicit special case here, same as `recentsVirtualURL` gets today.
- Directory listing is produced by
  `FileSystemService.loadDirectoryContents(at:options:)`
  (`Services/FileSystem/FileSystemService.swift:32-37`), called from
  `AppState.refreshCurrentDirectory()`.
- **Existing precedent for a "virtual folder"**: `AppState.recentsVirtualURL`
  (`AppState.swift:57`, `URL(fileURLWithPath: "/virtual/recents")`) is already
  special-cased in `navigateTo`, directory monitoring start, and
  `FileSystemService.loadDirectoryContents`. This is the closest existing pattern to
  imitate for a virtual zip "folder" under Option B.
- `FileItem` (`Models/FileItem.swift:31-82`) has no synthetic-metadata constructor —
  it always reads real `URL.resourceValues`.
- Double-click today: `FileListView.swift:243-244` and `FileGridView.swift:172` both
  call `appState.navigateTo(item.url)` for files and directories alike;
  `FileColumnView.swift` uses single-tap selection with its own reveal logic. Single
  choke point for "open a file" is `completeNavigation`'s `NSWorkspace.shared.open(url)`
  (`AppState+Navigation.swift:52`).
- `ArchiveService.isArchive(url:)` currently only used from the context-menu path
  (`Views/Components/SharedViewHelpers.swift:213-221`) that opens the current
  `ArchiveInspectionSheetView` sheet — double-click doesn't check it at all today.
- `DirectoryMonitor` (`Models/DirectoryMonitor.swift`) wraps FSEvents directly on a
  path string — would need to no-op (like it already effectively does for
  `/virtual/recents`) for a virtual zip path.

## Recommendation
Go with **Option A** (extract-to-temp-then-navigate) unless zero-upfront-extraction is
a hard requirement (e.g. very large archives where extracting everything up front is
unacceptable) — it delivers the requested UX (double-click opens like a folder,
navigate normally, double-click a file inside extracts+opens) for a fraction of the
effort and risk of Option B.

Not started — this file is a scoping/assessment note, no implementation yet.
