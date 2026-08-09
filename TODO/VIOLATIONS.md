
### `Sources/Wiles/Views/Content/FileListView.swift:234-260` — `FileRowInteractionsModifier` duplicates `FileItemInteractionsModifier`
**Priority: Medium** — rule 1 explicitly names drag/context-menu/hover handling as must-not-duplicate;
this reimplements `onDrag`/`RightClickDetector`/context-menu plumbing that `FileGridView`/`FileColumnView`
already share via one modifier.
**Complexity: Complex** — consolidating requires extending the shared modifier with the row-specific
extra params (`springLoadedFolder`/`onTargetedChanged`) without regressing grid/column behavior;
real risk of subtle behavioral drift if rushed. Deliberately skipped in the 2026-08-08 batch fix
because this exact file's double-click gesture wiring had just been stabilized after a real
regression that session (see git history) — touching it again in a rushed/parallel pass was judged
too risky. Worth doing carefully, on its own, when there's time to manually verify List/Grid/Column
double-click and drag behavior afterward.

### `ArchiveInspectionService.swift:35` — `readDataToEndOfFile()` buffers subprocess stdout in one shot
**Priority: Low** — archive *listings* are small text output even for large archives; the risk
is theoretical unless someone opens an archive with an enormous entry count.
**Complexity: Moderate** — would need a streaming reader instead of a one-shot read; not worth
it unless it's an actual reported problem. Note: as of 2026-08-08, `listEntries` no longer shells
out to `unzip`/`Process` at all (it parses the ZIP central directory directly via
`ZIPCentralDirectoryReader` — see `ArchiveInspectionService.swift`'s `listEntries`), so this
specific line/finding may already be stale; only `extractSingleEntry` still uses `Process`, and
its `try process.run()` is already non-silent (not what this finding was about). Re-verify line
numbers before picking this up.


#11 (FileRowInteractionsModifier): "real risk of subtle behavioral drift if rushed... too risky" — o "ia mudar muito".
#14 (ArchiveInspectionService streaming): "not worth it unless it's an actual reported problem" — o "não valia a pena".
