# WILES_UI_UX_RULES.md — Wiles UI/UX Rules

Visual design and interaction conventions specific to the Wiles app — how its screens, controls, and copy should look, read, and behave. Generic Apple HIG/SwiftUI patterns (alignment conventions, `.contentShape` mechanics, window-scoped state) live in `SWIFT_LANG_RULES.md`; everything else about the app lives in `WILES_RULES.md`.

## Standard Modal/Sheet Screen Pattern (MANDATORY for every new sheet/modal)

Every modal in this app (`AutoOrganizationSheet`, `HelpSheet`, `AboutSheet`, `SettingsView`, `FilePropertiesSheet`, `SymlinkSheetView`, `FolderPickerSheet`, `BatchRenameSheetView`, `ImageConverterSheetView`, `ArchiveInspectionSheetView`, `DuplicateCleanerSheetView`, `HttpShareSheet`, etc.) follows the exact same skeleton. When adding or editing a modal, copy this pattern rather than improvising:

- **Structure**: `VStack { headerView; Divider(); contentArea; Divider(); footerView }`. Content between the two `Divider()`s is the only part that scrolls/grows; header and footer stay fixed.
- **Always present as a real `.sheet(isPresented:)`, never as its own `Scene`** — a `Scene` comes with native title-bar/traffic-light chrome that visually fights this pattern and can't be reliably stripped (`.windowStyle(.hiddenTitleBar)` has no effect on a `Settings` scene; reaching into the real `NSWindow` via `NSViewRepresentable` still leaves rendering glitches). A sheet has no window chrome to begin with — see `SettingsView.swift`, wired through `windowUIState.showSettingsSheet` like every other sheet flag.
- **Multi-tab screens**: put the tab switcher *inside* `headerView`, below the icon/title/subtitle row. Don't use `Picker(selection:).pickerStyle(.segmented)` if tabs need icons — macOS silently drops the icon from a `Label` there even with `.labelStyle(.titleAndIcon)`. Hand-roll the tab row instead — see `SettingsView.swift`'s `tabSwitcher`.
- **Header**: leading icon + `VStack(alignment: .leading, spacing: 2)` with a bold title and a one-line secondary subtitle beneath it (`.font(.system(size: 11))`, `.foregroundColor(.secondary)`) — never ship a header with just a bare title. Give the header a subtle background tint (`.background(Color(NSColor.controlBackgroundColor).opacity(0.5))`) when the sheet has enough visual weight to need one. **Never put a close/X button in the header** — every sheet closes exclusively through the footer.
- **Footer**: `HStack { Spacer(); primaryButton }` — right-aligned, never centered/left-aligned. Primary action carries `.keyboardShortcut(.defaultAction)`. For Cancel/Confirm, place `Cancel` immediately before the primary button in the same right-aligned `HStack`, with `.keyboardShortcut(.escape, modifiers: [])`.
- **Closing on Escape**: real `.sheet(...)` views get this for free. The exception is a view NOT presented via `.sheet(...)` (e.g. `ShortcutsHUDOverlay`, a manual full-window `ZStack` overlay) — wire it explicitly with an invisible `Button("") { ... }.keyboardShortcut(.escape, modifiers: []).hidden()` (not `.onExitCommand`, which only fires when something in the subtree holds keyboard focus — a manual overlay never establishes that). Make sure no other view (e.g. `MainContentView`'s global hidden Escape button) is still capturing Escape first; `.disabled(...)` it while the overlay shows if so.
- **Container chrome**: fixed `.frame(width:, height:)` (or width-only) on the outermost `VStack`, plus `.background(Color(NSColor.windowBackgroundColor))` — every sheet needs this background.
- **Padding**: per-section (header, footer, content area's own inner container), not one blanket `.padding(20)` on the whole `VStack`. A scrollable content area extends its `ScrollView` close to the container's true edges; its own inner content keeps the same horizontal padding as header/footer for alignment.

## Custom Tappable Controls — Repeat Offender, Check Every Time

See `SWIFT_LANG_RULES.md`'s `.contentShape` rule for the general technique. This has shipped as a real bug more than once in this app — most recently `SettingsView.swift`'s tab row, where outset hit regions on adjacent tabs caused clicking "General" to select a different tab. Treat this as a mandatory check on every custom tappable control, not something patched in reactively after a report.

## Minimalist Menu Labels

Menu items and short UI labels should be minimalist, not redundant — if context already makes the subject obvious, don't restate it (e.g. "About", not "About Wiles" — a deliberate product choice, even though it diverges from Apple's own HIG convention; not something to "correct" back). Also avoid em-dashes ("—") in short user-facing copy (About sheet text, Help overview) — use periods/short sentences instead.

## No Dev Jargon in User-Facing Copy

User-facing copy (About/Help sheets, public README, `RELEASE_NOTES.md` — including technical-sounding sections and the consolidated summary) must never mention implementation technology (Swift, SwiftUI, Electron, AppKit) or dev-facing terms (threads, caches, race conditions, API/class names like `NSSharingService`, `FSEvents`, `UserDefaults`). No "technical section is exempt" carve-out. Outcome-oriented words ("native", "instant", "focused", "considered", "no bloat") are fine. A bug fix with zero user-visible effect doesn't get a changelog entry at all. Don't name or compare against competitors — position Wiles on its own qualities.

## Minimal UI Changes

When fixing a specific bug in an existing view, don't also redesign the layout beyond what was asked — no widening, no splitting into columns, no restructuring "while in there," even if it seems like better use of space. Scope UI edits tightly to the literal ask; propose a genuine layout improvement separately if one seems warranted.

## Capture UI/UX Rules as They're Found

When making a UI/UX fix (spacing, alignment, control choice, dividers, etc.), check whether the reasoning generalizes beyond this one screen. If it does, add it to this file in the same turn, not just fix the one instance. Rules must be written **generically** — no reference to the specific file/function/bug that prompted them. Prefer extending an existing related rule over creating a new one for every small addition, unless the topic is genuinely distinct.
