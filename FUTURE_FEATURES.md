# 🚀 Wiles: Roadmap & Feature Tracker (Top 58)

This document provides a comprehensive roadmap of **58 features, enhancements, and roadmap items** for **Wiles** (Native macOS File Manager). Each item is written in English and tagged with its current status in the codebase (v0.0.5).

### Status Legend
- ✅ **Completed** — Fully implemented and available in Wiles.
- 🚧 **In Progress / Partial** — Foundation or partial implementation built.
- ⏳ **Planned** — Scheduled for future releases.

---

## ⭐️ Category 1: Essential & Standard Features
*Fundamental capabilities expected in modern file managers.*

1. ✅ **Sort By Options**: Sorting by Name, Date Modified, Size, and Kind across Grid and List views.
2. ✅ **Icon Size Scaling**: Dynamic icon sizing for Grid View stored persistently in user preferences.
3. ✅ **Sidebar Favorites & Navigation**: Sidebar navigation featuring Favorites, Mac, Devices, Recents, and Directory Tree.
4. ✅ **Trash Management**: Native "Move to Trash" support via keyboard shortcuts and context menus.
5. 🚧 **New File / Folder Creation**: Native New Folder sheet implemented; template-based "New File" menu planned.
6. ⏳ **Multi-Tab Navigation**: Safari/Finder-style tabs for opening multiple directories within a single window.
7. ⏳ **Column View (Miller Columns)**: Miller columns layout for deep, hierarchical directory traversal.
8. ⏳ **Undo / Redo (`Cmd+Z` / `Cmd+Shift+Z`)**: Ability to undo file operations (move, copy, rename, delete).
9. ⏳ **Background Operations Manager**: Status bar popover/window tracking concurrent file operations with pause/cancel controls.
10. ⏳ **Native macOS Tags Support**: View, add, filter, and modify colored macOS Finder tags.
11. ⏳ **Eject External Volumes**: Native eject button next to external drives, USB storage, and mounted DMGs in the sidebar.
12. ⏳ **Connect to Server GUI**: Dialog for mounting network storage (SMB, AFP, NFS, FTP).
13. ⏳ **macOS Services Integration**: Right-click access to macOS system Services (Automator, Shortcuts, Quick Actions).
14. ⏳ **Per-Folder Layout Memory**: Remember View Mode (Grid vs List) on a per-directory basis.

---

## ⚡️ Categoria 2: Productivity & Developer Workflow
*Power tools designed for developers and heavy workflows.*

15. ✅ **Right Preview Sidebar**: Collapsible right sidebar rendering live file metadata, media previews, and dimensions.
16. ✅ **File Properties Inspector**: Modernized properties sheet displaying file paths, size, dates, permissions, and MIME types.
17. ✅ **Native Image Converter**: Image conversion service supporting PNG, JPEG, HEIC, TIFF, with JPEG quality control.
18. ✅ **Batch Renamer**: Dedicated batch rename service supporting prefix, suffix, search & replace, and numbering patterns.
19. 🚧 **Advanced Search**: Header search bar with auto-focus, real-time filtering, and shortcut activation; Regex planned.
20. 🚧 **Archive Management**: Native ZIP compression and extraction via `ZipArchiveService`; `.7z`/`.rar` expansion planned.
21. ⏳ **Dual-Pane Mode (Commander Style)**: Side-by-side independent navigation panes for rapid keyboard-driven file transfers.
22. ⏳ **Integrated Terminal Panel**: Built-in terminal drawer synced with the current working directory (`pwd`).
23. ⏳ **Git Status Integration**: File and folder badges indicating Git status (Modified, Untracked, Ignored).
24. ⏳ **Quick "Open In..."**: Direct toolbar buttons to launch the current folder in VS Code, Cursor, Xcode, or Terminal.
25. ⏳ **Symlink Creator GUI**: Interface to generate absolute and relative symbolic links (`ln -s`).
26. ⏳ **Checksum / Hash Calculator**: Property tab to calculate and copy MD5, SHA1, and SHA256 hashes.
27. ⏳ **File Splitter & Joiner**: Tool to chunk large files into smaller parts and merge them back.
28. ⏳ **Keep Folders on Top**: Preference setting to force folders to sort above files regardless of sort mode.
29. ⏳ **Copy File Path Modes**: Right-click menu options to copy Absolute, Relative, URI (`file://`), or Terminal-escaped paths.
30. ⏳ **Markdown & Code Syntax Previewer**: Live syntax-highlighted code rendering in the preview sidebar.
31. ⏳ **Smart Folders**: Save complex search queries as dynamic virtual folders in the sidebar.

---

## 🎨 Category 3: Native macOS Design & UI/UX
*Aesthetics and UI polish following Apple Human Interface Guidelines (HIG).*

32. ✅ **Native Translucent Glassmorphism**: Vibrant AppKit and SwiftUI material translucency across windows, sidebars, and headers.
33. ✅ **Startup Permission Manager**: Asynchronous startup routine (`PermissionService`) auditing Desktop, Documents, and Downloads access.
34. ✅ **Native About & Help Modals**: Custom SwiftUI About and Help sheets replacing default system dialogs.
35. ⏳ **Customizable Toolbar**: Drag-and-drop toolbar editor to add, remove, and reorder controls.
36. ⏳ **Custom Folder Colors & Icons**: Assign custom colors or emoji icons to specific folders.
37. ⏳ **Accent Color Override**: Custom accent color selection overriding system defaults.
38. ⏳ **Compact Density Layout**: Toggleable tight spacing mode for smaller MacBook screens.
39. ⏳ **Keyboard Shortcut Re-mapper**: Preference pane to customize all application hotkeys.
40. ⏳ **Context Menu Customizer**: Hide unused context menu actions for a cleaner experience.
41. ⏳ **Dynamic Folder Backgrounds**: Custom background images or watermarks per directory.

---

## ☁️ Category 4: Cloud, Network & Connectivity
*Seamless remote filesystem access and file sharing.*

42. ⏳ **Native SFTP / SSH Browser**: Browse remote Linux servers securely without mounting.
43. ⏳ **S3 / R2 Bucket Manager**: Native object storage browser for AWS S3 and Cloudflare R2.
44. ⏳ **AirDrop Integration**: Context menu and toolbar actions to trigger native AirDrop transfer.
45. ⏳ **Cloud Sync Badges**: Sync state indicators for iCloud, Google Drive, and Dropbox.
46. ⏳ **Bonjour Network Discovery**: Automatic sidebar population of local network computers and shares.
47. ⏳ **Instant Local HTTP Share**: Spin up an instant temporary local HTTP server to share a folder over Wi-Fi.

---

## 🔥 Category 5: Power User Capabilities
*Unique features distinguishing Wiles from traditional file explorers.*

48. ✅ **Folder Disk Space Visualizer**: Disk visualizer breaking down folder space usage with a Top 10 heavy files list.
49. ⏳ **Built-in Hex Viewer**: Hexadecimal inspection tab in the preview sidebar for binary files.
50. ⏳ **Regex Batch Rename Expansion**: Support for regular expression capture groups (`$1`, `$2`) in batch renaming.
51. ⏳ **File Shredder (Secure Erase)**: Multi-pass zero-overwrite deletion bypassing the Trash.
52. ⏳ **RAM Disk Creator**: One-click RAM disk creation for ultra-fast temporary storage.
53. ⏳ **Drop Stack (File Shelf)**: Floating temporary collection shelf for gathering files across directories.
54. ⏳ **Folder Auto-Organization**: Rule-based file routing (e.g. automatically moving PDFs to Documents).
55. ⏳ **UNIX File Lock Toggle**: Quick toggle for UNIX `uchg` (immutable) file flags.
56. ⏳ **Directory Diff & Comparison**: Side-by-side folder comparison highlighting missing or updated files.
57. ⏳ **App Uninstaller**: Full `.app` removal tool detecting leftover cache and preference files in `~/Library`.
58. ⏳ **Ghost Mode (Stealth Browsing)**: Temporarily suppress `.DS_Store` creation and recent file history logging.

---

## 📊 Summary Statistics
- ✅ **Completed Features**: 12
- 🚧 **In Progress / Partial**: 3
- ⏳ **Planned Features**: 43
- **Total Tracked Features**: 58
