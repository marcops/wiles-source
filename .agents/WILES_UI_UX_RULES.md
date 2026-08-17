# WILES_UI_UX_RULES.md — Wiles UI/UX Rules

Visual design and interaction conventions specific to the Wiles app — how its screens, controls, and copy should look, read, and behave. Generic Apple HIG/SwiftUI patterns (alignment conventions, `.contentShape` mechanics, window-scoped state) live in `SWIFT_LANG_RULES.md`; everything else about the app lives in `WILES_RULES.md`.

## Standard Modal/Sheet Screen Pattern (MANDATORY for every new sheet/modal)

Every modal in this app (`AutoOrganizationSheet`, `HelpSheet`, `AboutSheet`, `SettingsView`, `FilePropertiesSheet`, `SymlinkSheetView`, `FolderPickerSheet`, `BatchRenameSheetView`, `ImageConverterSheetView`, `ArchiveInspectionSheetView`, `DuplicateCleanerSheetView`, `HttpShareSheet`, `ConnectToServerSheetView`, `PasswordCompressSheetView`, `FeedbackSheetView`, etc.) is built on `ModalScaffoldView` (`Sources/Wiles/Views/Components/Modal/ModalScaffoldView.swift`) — never hand-roll the header/content/footer skeleton in a new or edited modal. Every sheet in the app has been migrated onto it; add any new one the same way.

`ModalScaffoldView` owns the parts that must be identical across every modal, so they can't drift screen to screen the way they used to:
- The `VStack { header; Divider(); content; Divider(); footer }` structure, with header/content/footer all sharing one background (`Color(NSColor.windowBackgroundColor)`) — no per-section tinting, so header/body/footer always read as one surface.
- Header icon (`ModalIcon`: `.appIcon`, `.symbol(String)`, or `.image(NSImage)`, all rendered into the same fixed-size slot), title, and one-line secondary subtitle — never ship a header with just a bare title. `showsHeader: Bool` (default `true`) toggles the header row and its divider off entirely, for a modal whose identity reads better as centered content than a left-aligned banner — see `AboutSheet`. Header and footer are their own composed types (`ModalHeaderView`, `ModalFooterView`), not inlined into the scaffold.
- Footer layout: right-aligned `HStack { Spacer(); [secondaryButton]; primaryButton }`, primary always `.controlSize(.large)` with `.keyboardShortcut(.defaultAction)`, secondary (when present) with `.keyboardShortcut(.escape, modifiers: [])`. Pass buttons via `ModalFooterButton`, never build footer buttons by hand.
- **Never put a close/X button in the header** — every sheet closes exclusively through the footer.

What callers still supply per-modal, via the scaffold's parameters:
- `content`: the actual body — fully custom per modal (a `Form`, a `List`, a custom `ScrollView`, tri-state loading/results/empty views, etc.). The scaffold does not impose scrolling or padding on it — a scrollable content area manages its own `ScrollView` and keeps the same horizontal padding as header/footer for alignment.
- `headerAccessory` (optional): anything that belongs below the icon/title/subtitle row inside the header — most commonly a tab switcher. Don't use `Picker(selection:).pickerStyle(.segmented)` if tabs need icons — macOS silently drops the icon from a `Label` there even with `.labelStyle(.titleAndIcon)`. Hand-roll the tab row instead — see `SettingsView.swift`'s `tabSwitcher`.
- `width`/`height` (frame) — sized per modal's actual content.
- `iconSize` (optional, defaults to the standard 36×36 slot): only override this when the icon itself is the subject being inspected, not a decorative/identity icon — e.g. `FilePropertiesSheet` shows the actual file's icon at a larger size (Finder "Get Info" style). An app-identity icon (`.appIcon`, feature glyphs) always stays at the default size for consistency.

Presentation and dismissal, unchanged by the scaffold:
- **Always present as a real `.sheet(isPresented:)`, never as its own `Scene`** — a `Scene` comes with native title-bar/traffic-light chrome that visually fights this pattern and can't be reliably stripped (`.windowStyle(.hiddenTitleBar)` has no effect on a `Settings` scene; reaching into the real `NSWindow` via `NSViewRepresentable` still leaves rendering glitches). A sheet has no window chrome to begin with — see `SettingsView.swift`, wired through `windowUIState.showSettingsSheet` like every other sheet flag.
- **Closing on Escape**: real `.sheet(...)` views get this for free. The exception is a view NOT presented via `.sheet(...)` (e.g. `ShortcutsHUDOverlay`, a manual full-window `ZStack` overlay) — wire it explicitly with an invisible `Button("") { ... }.keyboardShortcut(.escape, modifiers: []).hidden()` (not `.onExitCommand`, which only fires when something in the subtree holds keyboard focus — a manual overlay never establishes that). Make sure no other view (e.g. `MainContentView`'s global hidden Escape button) is still capturing Escape first; `.disabled(...)` it while the overlay shows if so.

## Custom Tappable Controls — Repeat Offender, Check Every Time

See `SWIFT_LANG_RULES.md`'s `.contentShape` rule for the general technique. This has shipped as a real bug more than once in this app — most recently `SettingsView.swift`'s tab row, where outset hit regions on adjacent tabs caused clicking "General" to select a different tab. Treat this as a mandatory check on every custom tappable control, not something patched in reactively after a report.

## Minimalist Menu & Button Labels

Menu items, footer button labels, and other short UI labels should be minimalist, not redundant — if the surrounding context (the modal's own title/subtitle, a visible selection UI) already makes the subject obvious, a button doesn't need to restate it (a "Move to Trash" primary button next to a checkbox-selection list doesn't need to spell out "Selected Duplicates" — the dialog title and the checkboxes already say that). Reuse an existing localization key for the shortened phrase when one already exists elsewhere in the app instead of adding a near-duplicate string. The one required exception is the app menu's "About" item, which follows Apple's own HIG convention and always includes the app name ("About Wiles", not bare "About"). Also avoid em-dashes ("—") in short user-facing copy (About sheet text, Help overview) — use periods/short sentences instead.

## No Dev Jargon in User-Facing Copy

User-facing copy (About/Help sheets, public README, `RELEASE_NOTES.md` — including technical-sounding sections and the consolidated summary) must never mention implementation technology (Swift, SwiftUI, Electron, AppKit) or dev-facing terms (threads, caches, race conditions, API/class names like `NSSharingService`, `FSEvents`, `UserDefaults`). No "technical section is exempt" carve-out. Outcome-oriented words ("native", "instant", "focused", "considered", "no bloat") are fine. A bug fix with zero user-visible effect doesn't get a changelog entry at all. Don't name or compare against competitors — position Wiles on its own qualities.

## Minimal UI Changes

When fixing a specific bug in an existing view, don't also redesign the layout beyond what was asked — no widening, no splitting into columns, no restructuring "while in there," even if it seems like better use of space. Scope UI edits tightly to the literal ask; propose a genuine layout improvement separately if one seems warranted.

## Capture UI/UX Rules as They're Found

When making a UI/UX fix (spacing, alignment, control choice, dividers, etc.), check whether the reasoning generalizes beyond this one screen. If it does, add it to this file in the same turn, not just fix the one instance. Rules must be written **generically** — no reference to the specific file/function/bug that prompted them. Prefer extending an existing related rule over creating a new one for every small addition, unless the topic is genuinely distinct.
