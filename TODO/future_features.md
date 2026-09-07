# Future features / usability ideas

Observations from building the AXUIElement UI-test suite (`UITestRunner/`). Not bugs — the
app behaves as designed; these are gaps a file-manager user would expect to find.

## Type-ahead row selection
Typing a letter (or a few letters quickly) in the file list should jump the selection to the
next item whose name starts with that text — Finder, GNOME Files, Windows Explorer all do
this. Wiles currently has no keyboard row-jump, so navigating a long folder means the mouse
or arrow keys only. A test scenario for this was written and then dropped because the feature
doesn't exist.

## "Rename" belongs in the menu bar
Rename (single-file inline) and Batch Rename (multi-select) are only reachable from the
right-click context menu. There's no File-menu item and no visible keyboard shortcut, so the
batch-rename sheet — one of the app's nicer features — is easy to miss entirely. Adding
`File ▸ Rename…` (enabled on any selection, opening the batch sheet for 2+ items) plus a
shortcut would make it discoverable.

## Search Filters menu is hidden
The "Search Filters" control (scope: file name / file content, `kind:` tokens) only appears
once the search field is open and is easy to overlook. A small always-visible affordance, or
surfacing the scope toggle next to the field, would help people find content search.

## Restore-from-Trash feedback
Undo of "Move to Trash" restores the file but gives no progress indication while it scans the
Trash, which can take a couple of seconds for a large item — a brief "Restoring…" state (as
other long operations already show) would reassure the user it's working.
