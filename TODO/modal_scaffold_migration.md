# ModalScaffoldView Migration — Remaining Sheets

`ModalScaffoldView` (`Sources/Wiles/Views/Components/Modal/`) is the mandatory header/content/footer
skeleton for every modal (see `WILES_UI_UX_RULES.md`). `SettingsView`, `HelpSheet`, and
`DuplicateCleanerSheetView` are already migrated as the reference implementations. The 10 sheets
below are not yet migrated — ordered easiest to hardest to change, each entry noting what it needs
to fit the scaffold's API (`icon`/`title`/`subtitle`/`width`/`height`/`primaryButton`/`secondaryButton`/`headerAccessory`/`content`).

## Easy — already has the full skeleton, just needs wiring + footer button fix

- **ImageConverterSheetView** — background already matches the standard; only the footer's primary
  button is undersized (no `.controlSize(.large)`). Smallest fix in this list — could be done as a
  standalone button-size fix even before full scaffold migration if that's wanted sooner.
- **AutoOrganizationSheet** — already has the full header/Divider/content/Divider/footer skeleton
  and a correctly-sized footer button; straightforward drop-in. Presents `FolderPickerSheet` as a
  nested sheet — verify that still works once wrapped in `ModalScaffoldView`.
- **FolderPickerSheet** — already has the full skeleton with a correctly-styled header. Footer primary
  button has no `.controlSize(.large)` (too small). Content (favorites sidebar + tree + path field) is
  unaffected, stays custom.
- **ArchiveInspectionSheetView** — has header/Divider/content/Divider/footer already but with
  spacing 12 (not 0) and a single blanket `.padding()` instead of per-section padding. Footer button
  has no `.controlSize(.large)`/`.borderedProminent`. Content is a `List`, stays custom.

## Moderate — has the shape but needs some rework

- **FeedbackSheetView** — already close to the target shape (header row, subtitle, Dividers). Footer
  swaps between 1 and 2 buttons depending on submit state — map that to `secondaryButton: nil` in the
  success state.

## Harder — flat `VStack`, needs the header/Divider/footer structure built from scratch

- **PasswordCompressSheetView** — smallest/simplest file of the flat group (37 lines): no icon, no
  subtitle, no Dividers, no background. Footer buttons have no `.controlSize(.large)`. Also: its title
  is the literal string `"OK"`, not localized via `appState.tr` — separate bug, worth fixing in the
  same pass.
- **SymlinkSheetView** — flat `VStack`, no Dividers, no background. Footer buttons have no
  `.controlSize(.large)`.
- **BatchRenameSheetView** — flat `VStack` with a segmented `Picker` as a standalone row below the
  title (a good candidate for the scaffold's `headerAccessory` slot instead). Footer buttons have no
  `.controlSize(.large)`.
- **ConnectToServerSheetView** — flat `VStack`, no header/footer split, no Dividers, no background.
  Footer primary button has no `.controlSize(.large)` (too small). Also has a conditional "recent
  servers" section with its own inline `ScrollView` to carry over carefully.
- **HttpShareSheet** — uses a `Spacer()` instead of a `Divider()` before the footer; no header
  background, no outer background. Footer button has no `.controlSize(.large)`/`.borderedProminent`.
  Content swaps between configuring/active/starting sub-states and stops a server `onDisappear` —
  preserve that lifecycle hook when restructuring. Riskiest of the flat group due to that lifecycle
  coupling.

## Blocked — needs a design decision before any code change

- **FilePropertiesSheet** — uses a 64×64 item icon and two subtitle-like lines (kind + size), both
  larger/different from the scaffold's standard 36×36 icon + single subtitle. Needs a decision: shrink
  the icon to fit the standard slot, or combine kind+size into one subtitle line. Footer button has no
  `.controlSize(.large)`/`.borderedProminent` (too small).
- **AboutSheet** — has no header row at all today; icon/title/subtitle are centered content, not a
  left-aligned header bar. Needs a design decision on whether to normalize to the standard
  left-aligned header (losing the current centered "about box" look) or special-case it — ask before
  migrating.

General pattern seen across most of these: whenever a footer button was styled with
`.buttonStyle(.borderedProminent)` but no `.controlSize(.large)`, it renders smaller than the
scaffold's standard primary button — this is the exact bug the user originally flagged on the
Duplicate Cleaner sheet, and it recurs in nearly every un-migrated sheet above.
