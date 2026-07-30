# 🚀 Wiles: Roadmap of Pending & Planned Features

This document tracks **50 upcoming planned features** for **Wiles** (Native macOS File Manager). All completed features (including New File Templates, Regex & Content Search, and Multi-format Archive Extraction) have been recorded in completed state.

---

## ⭐️ Category 1: Essential & Core Navigation (10 Items)
1. **Multi-Tab Navigation**: Safari/Finder-style tabs for opening multiple directories within a single window.
2. **Column View (Miller Columns)**: Miller columns layout for deep, hierarchical directory traversal.
3. **Undo / Redo (`Cmd+Z` / `Cmd+Shift+Z`)**: Native undo/redo engine for file operations (move, copy, rename, delete).
4. **Background Operations Manager**: Status bar popover/window tracking concurrent file operations with pause/cancel controls.
5. **Native macOS Tags Support**: View, add, filter, and modify colored macOS Finder tags.
6. **Eject External Volumes**: Native eject button next to external drives, USB storage, and mounted DMGs in the sidebar.
7. **Connect to Server GUI**: Native dialog for mounting network storage (SMB, AFP, NFS, FTP).
8. **macOS Services Integration**: Right-click access to system Services (Automator, Shortcuts, Quick Actions).
9. **Per-Folder Layout Memory**: Remember View Mode (Grid vs List) on a per-directory basis.
10. **Folder Pinning & Quick Navigation Bar**: Pin frequently accessed directories to a persistent quick-access bar below the header.

---

## ⚡️ Category 2: Developer & Power-User Tools (13 Items)
11. **Dual-Pane Mode (Commander Style)**: Side-by-side independent navigation panes for rapid keyboard-driven file transfers.
12. **Integrated Terminal Panel**: Built-in terminal drawer synced with the current working directory (`pwd`).
13. **Git Status Integration**: File and folder badges indicating Git status (Modified, Untracked, Ignored).
14. **Quick "Open In..."**: Direct toolbar buttons to launch the current folder in VS Code, Cursor, Xcode, or Terminal.
15. **Symlink Creator GUI**: Interface to generate absolute and relative symbolic links (`ln -s`).
16. **Checksum / Hash Calculator**: Property tab to calculate and copy MD5, SHA1, and SHA256 hashes.
17. **File Splitter & Joiner**: Tool to chunk large files into smaller parts and merge them back.
18. **Keep Folders on Top**: Preference setting to force folders to sort above files regardless of sort mode.
19. **Copy File Path Modes**: Right-click menu options to copy Absolute, Relative, URI (`file://`), or Terminal-escaped paths.
20. **Markdown & Code Syntax Previewer**: Live syntax-highlighted code rendering in the preview sidebar.
21. **Smart Folders**: Save complex search queries as dynamic virtual folders in the sidebar.
22. **Advanced Archive Support (`.7z`, `.rar`, `.tar.gz`)**: Full extraction and creation support beyond standard ZIP archives.
23. **Regex Content Search**: Search file contents using Regular Expressions and Spotlight indexing.

---

## 🎨 Category 3: Design & UI Customization (8 Items)
24. **Customizable Toolbar**: Drag-and-drop toolbar editor to add, remove, and reorder controls.
25. **Custom Folder Colors & Icons**: Assign custom colors or emoji icons to specific folders.
26. **Accent Color Override**: Custom accent color selection overriding system defaults.
27. **Compact Density Layout**: Toggleable tight spacing mode for smaller MacBook screens.
28. **Keyboard Shortcut Re-mapper**: Preference pane to customize all application hotkeys.
29. **Context Menu Customizer**: Hide unused context menu actions for a cleaner experience.
30. **Dynamic Folder Backgrounds**: Custom background images or watermarks per directory.
31. **Quick Look Extensions**: Enhanced Quick Look plugins for rendering 3D models, SVG vectors, and CAD files.

---

## ☁️ Category 4: Cloud, Network & Sharing (6 Items)
32. **Native SFTP / SSH Browser**: Browse remote Linux servers securely without mounting globally.
33. **S3 / R2 Bucket Manager**: Native object storage browser for AWS S3 and Cloudflare R2.
34. **AirDrop Integration**: Context menu and toolbar actions to trigger native AirDrop transfer.
35. **Cloud Sync Badges**: Sync state indicators for iCloud, Google Drive, and Dropbox.
36. **Bonjour Network Discovery**: Automatic sidebar population of local network computers and shares.
37. **Instant Local HTTP Share**: Spin up an instant temporary local HTTP server to share a folder over Wi-Fi.

---

## 🔥 Category 5: Advanced & Unique Features (13 Items)
38. **Built-in Hex Viewer**: Hexadecimal inspection tab in the preview sidebar for binary files.
39. **Regex Batch Rename Expansion**: Support for regular expression capture groups (`$1`, `$2`) in batch renaming.
40. **File Shredder (Secure Erase)**: Multi-pass zero-overwrite deletion bypassing the Trash.
41. **RAM Disk Creator**: One-click RAM disk creation for ultra-fast temporary storage.
42. **Drop Stack (File Shelf)**: Floating temporary collection shelf for gathering files across directories.
43. **Folder Auto-Organization**: Rule-based file routing (e.g. automatically moving PDFs to Documents).
44. **UNIX File Lock Toggle**: Quick toggle for UNIX `uchg` (immutable) file flags.
45. **Directory Diff & Comparison**: Side-by-side folder comparison highlighting missing or updated files.
46. **App Uninstaller**: Full `.app` removal tool detecting leftover cache and preference files in `~/Library`.
47. **Ghost Mode (Stealth Browsing)**: Temporarily suppress `.DS_Store` creation and recent file history logging.
48. **Duplicate File Finder**: Scan directories for exact duplicate files by hash/content to free up disk space.
49. **Media Tag Editor**: Edit ID3 tags for audio files (MP3/FLAC) and EXIF metadata for photos directly.
50. **Recursive Folder Size Calculation**: Asynchronous recursive folder size calculation for List View.
