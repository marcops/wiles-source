# Wiles — Architecture Review Backlog

Each item below is a **real architectural problem found in the source code**, validated against the Deep Audit Protocol (AGENTS.md Rule 29). Items are ordered by discovery. Fix and check off before releasing.

---

## Pending Fixes

### [ ] 1. `ArchiveInspectionService` — Unbounded IPC Buffer (OOM)
**Category:** Unbounded IPC & Stream Buffering (Rule 29.13)
**File:** `Sources/Wiles/Features/ArchiveInspector/ArchiveInspectionService.swift`
**Problem:** `extractSingleEntry` called `pipe.fileHandleForReading.readDataToEndOfFile()` and then `fileData.write(to:)`, loading the entire decompressed file content into RAM before writing to disk. Extracting a 4GB file would allocate 4GB in memory, causing macOS Jetsam (OOM termination).
**Required Fix:** Connect `Process.standardOutput` directly to a `FileHandle` opened for writing at the destination path, so the OS streams bytes from `unzip` straight to disk without ever buffering the full payload in RAM.
**Status:** ✅ Fixed in commit `de3f31c`

---

### [ ] 2. `ImageConverterSheetView` — Synchronous Image Decompression on Main Thread
**Category:** Main Thread Resource Decoding — Anti-Beachball (Rule 29.14)
**File:** `Sources/Wiles/Features/ImageConverter/ImageConverterSheetView.swift` (line 111)
**Problem:** `.onAppear` calls `NSImage(contentsOf: item.url)` directly on the `@MainActor`. For large RAW/TIFF images this decompresses a full-resolution bitmap synchronously on the UI thread, freezing the entire app (Beachball) for multiple seconds before the sheet even renders.
**Required Fix:** Dispatch the image load inside a `Task.detached`. Only assign the result back on `@MainActor` after decoding completes in the background.

---

### [ ] 3. `PasswordCompressSheetView` — Synchronous Subprocess on Button Closure
**Category:** Synchronous Subprocess Execution — Anti-Beachball (Rule 29.15)
**File:** `Sources/Wiles/Views/Modals/PasswordCompressSheetView.swift` (line 27)
**Problem:** The "OK" button closure calls `ArchiveService.compressToZIP(urls:in:password:)` directly, which internally launches a `Process` (zip) and calls `waitUntilExit()`. Since SwiftUI button closures execute on `@MainActor`, zipping a large folder with a password blocks the entire UI thread until the subprocess finishes — potentially for minutes.
**Required Fix:** Wrap the `compressToZIP` call inside a `Task.detached` block with a loading indicator, dispatching the result back to `@MainActor` on completion.

---

### [ ] 4. `DuplicateCleanerSheetView` — Sequential Bulk Disk I/O on `@MainActor`
**Category:** Sequential Bulk Disk I/O on the Main Actor — Anti-Beachball (Rule 29.16)
**File:** `Sources/Wiles/Features/DuplicateCleaner/DuplicateCleanerSheetView.swift` (lines 175–192)
**Problem:** `trashSelected()` uses `Task { @MainActor in }` and then loops over all selected URLs calling `FileSystemService.moveToTrash(url:)` one by one on the main thread. Trashing 500 duplicates means 500 sequential filesystem operations blocking the UI — the app will appear frozen for the entire duration.
**Required Fix:** Move the loop into a `Task.detached` block. Collect failures, then report the aggregate result back on `@MainActor`.

---

### [ ] 5. `AutoOrganizationService` — N+1 Attribute Fetching in Directory Scan
**Category:** N+1 Attribute Fetching in Directory Enumeration (Rule 29.17)
**File:** `Sources/Wiles/Services/AutoOrganizationService.swift` (line 124)
**Problem:** `processFolder(_:)` calls `fm.contentsOfDirectory(at:includingPropertiesForKeys:nil,...)` with `nil` property keys, then calls `fm.fileExists(atPath:isDirectory:)` inside the loop per file. This forces one `stat()` syscall per file to resolve `isDirectory` instead of pre-fetching all attributes in a single bulk call. In a watched Downloads folder with thousands of files, this means thousands of individual kernel round trips on the main queue.
**Required Fix:** Replace `nil` with `[.isDirectoryKey, .isHiddenKey]` in `includingPropertiesForKeys`, then read `resourceValues` from the URL inside the loop instead of calling `fileExists(atPath:isDirectory:)`.

---

### [ ] 6. `AppState+Operations.performBatchRename` — Sequential Rename I/O on `@MainActor`
**Category:** Sequential Bulk Disk I/O on the Main Actor — Anti-Beachball (Rule 29.16)
**File:** `Sources/Wiles/Models/AppState/AppState+ColumnsAndActions.swift` (line 87)
**Problem:** `performBatchRename` is a `@MainActor` function that calls `BatchRenameService.performBatchRename`, which internally loops over every file calling `FileSystemService.renameItem(at:newName:)` one by one, synchronously. Renaming 500 files one-by-one on the main thread will freeze the UI proportionally to file count.
**Required Fix:** Dispatch `BatchRenameService.performBatchRename` inside a `Task.detached`, returning results back to `@MainActor` on completion.

---

### [ ] 7. `LocalHttpServerService.serveFile` — Full File Loaded into RAM Before Send
**Category:** Unbounded IPC & Stream Buffering (Rule 29.13)
**File:** `Sources/Wiles/Features/HttpSharing/LocalHttpServerService.swift` (line 195)
**Problem:** `serveFile` calls `Data(contentsOf: fileURL)` which loads the entire file into RAM, then appends it to the HTTP response `Data` buffer. Serving a 4GB ISO over HTTP would attempt to allocate 4GB+ in memory, causing an OOM crash or severe memory pressure.
**Required Fix:** Stream the file in fixed-size chunks using `FileHandle.read(upToCount:)` in a loop, sending each chunk via `NWConnection.send` before reading the next one.

---

### [ ] 8. `PreviewSidebarView` — Synchronous File Read Inside SwiftUI `body`
**Category:** Main Thread Resource Decoding — Anti-Beachball (Rule 29.14)
**File:** `Sources/Wiles/Views/Sidebar/PreviewSidebarView.swift` (line 63)
**Problem:** The SwiftUI `body` computed property contains `try? String(contentsOf: item.url)` directly inline. This reads the entire file from disk synchronously on the main thread during every render pass triggered by a selection change. For large text files (logs, CSVs, generated code), this blocks the UI thread until the read completes.
**Required Fix:** Move the file read into `.task(id: item.url)`, storing the result in a `@State` variable. The body must only display pre-loaded `@State` content, never perform I/O.

---

## Items Being Investigated

*(scanning in progress…)*

---

### [ ] 9. `FileMetadataTooltipService` — Unbounded Dictionary Cache (Memory Leak)
**Category:** Defensive Memory Bounding for Caches (Rule 26)
**File:** `Sources/Wiles/Services/FileMetadataTooltipService.swift` (line 12)
**Problem:** `private static var cache: [String: String] = [:]` is a plain Swift dictionary with no eviction, count limit, or cost limit. Every file hovered during a session is cached forever. In a long session browsing directories with thousands of files, this dictionary grows without bound, silently consuming RAM until the OS pressure-kills the app.
**Required Fix:** Replace the raw dictionary with `NSCache<NSString, NSString>` with an explicit `countLimit` (e.g. 1000 entries), which automatically evicts entries under memory pressure.

---

### [ ] 10. `FileMetadataTooltipService` — Synchronous PDF Parse on Hover (`@MainActor`)
**Category:** Main Thread Resource Decoding — Anti-Beachball (Rule 29.14)
**File:** `Sources/Wiles/Services/FileMetadataTooltipService.swift` (line 54)
**Problem:** `extraInfo(for:)` calls `PDFDocument(url: item.url)` synchronously inside the hover handler on `@MainActor`. PDFKit parses the document header synchronously — for large multi-hundred-page PDFs (or PDFs on a slow network share) this blocks the entire UI thread on every first hover over a PDF file.
**Required Fix:** Move the `PDFDocument(url:)` and `CGImageSourceCreateWithURL` calls into an async `.task(id:)` block and cache the result in `@State`, never calling them on the main thread.

---

## Items Being Investigated

*(scanning in progress…)*

---

## Completed

- ✅ Rule 29 — Pre-Commit Deep Audit Protocol added to `AGENTS.md`
- ✅ `ArchiveInspectionService` — OOM fix via direct `FileHandle` streaming (commit `de3f31c`)
