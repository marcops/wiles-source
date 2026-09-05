# Development Principles

Generic software-engineering discipline — applies to any project, any language. Not Swift-specific (see `SWIFT_LANG_RULES.md`) and not Wiles-specific (see `WILES_RULES.md`).

## Absolute Compliance

- These rules are not suggestions; they are strict constraints. Follow them exactly. Never deliver code without checking it against the applicable rules first.
- **Always distrust assumptions — inspect authoritative source definitions.** Never guess property names, method signatures, or initializers. Read the actual source before relying on it.

## Core Architectural Principles (KISS, YAGNI, DRY, SRP)

- **KISS (Keep It Simple, Stupid)**: prefer straightforward, clean state management over over-engineered abstractions or unnecessary layers.
- **YAGNI (You Aren't Gonna Need It)**: build features strictly for concrete requirements. Avoid speculative code or unused generic wrappers.
- **DRY (Don't Repeat Yourself)**: never duplicate the same interaction/rendering/handling logic across multiple call sites — extract shared components/modifiers/functions instead.
- **Single Responsibility Principle (SRP)**: keep each unit (view/component, service, state container) focused on one concern.
- **No Inline Compound Conditions**: any `if`/`guard` combining 3 or more terms (`&&`/`||`/chained comparisons) MUST be extracted into a separate, well-named comparison function or computed property (e.g. `if isEligibleForBulkDelete(...)` instead of `if x || y || z`) instead of left as an inline boolean chain.
- (See `WILES_RULES.md` for how these map onto this app's actual views/services.)

## Architect Mode: Front-Load Design, Don't Wait to Be Corrected

When asked to act as architect / improve / design something (not just "fix X"), do the discovery and design pass **before** writing code, not incrementally as gaps get noticed:
- Audit exhaustively first (every call site, every instance of the pattern being touched) — don't rely on the user spotting what a fuller search would have found.
- Prefer explicit, self-documenting APIs (a named `Bool`/enum) over implicit signals (`nil` as a hidden "off" switch) unless there's a real ambiguity being modeled.
- Decompose by the project's own stated principles (SRP, one-type-per-file) from the first draft, not only after being told to split something up.
- When corrected, extract and state the general principle behind the fix (not just apply the one-off patch) so it generalizes to the next similar case without being asked again.

## No Magic Numbers or Unnamed Constants

- Never use raw magic numbers, arbitrary multipliers, or unexplained static offsets. Always define named constants/enums, or compute values dynamically from context.
- Placement depends on sharing, not on the value's type: if a constant is used by 2+ types/files, it belongs in the shared token enum (e.g. `LayoutTokens`/`MotionTokens`); if it's only used within one type, it belongs as a `private static let` inside that type, not in the shared file. Don't default to the shared file "to be safe" — that turns it into a dumping ground of single-use values and creates false coupling between unrelated views. Promote a local constant to the shared file only when a second real caller actually appears.

## No Unnecessary Comments

Comments in production code are prohibited by default. A comment is allowed only when ALL of these are true:
- The code contains a non-obvious exception, workaround, constraint, bug-related behavior, or external limitation that cannot be reasonably understood from the code itself.
- Removing the comment would create a real risk of the same mistake being reintroduced.
- The comment provides information that cannot be expressed more clearly by improving the code itself.

Prohibited even when well-intentioned: comments that merely describe what the code obviously does; comments that restate the method/variable/condition/implementation; comments explaining standard language/framework behavior; comments added only for readability when the code could instead be made self-explanatory; TODO/FIXME-style comments when the issue should be tracked externally instead; large explanatory blocks or embedded documentation; comments describing historical context no longer relevant.

When a comment is genuinely necessary, it MUST be short, specific, human-readable, immediately understandable, focused on the reason/constraint (not the implementation), and free of unnecessary technical detail. It explains *why* the unusual behavior exists, not *what* the code does.
- Good: `// Keep this delay: SumSub can send the webhook before the IDV record is committed.`
- Bad: `// Wait for 2 seconds before continuing.`

If the explanation needs a paragraph or more, that's a sign to improve the code's structure/naming instead of writing a long comment — never pad it into a comment block.

**Review test**: "If I remove this comment, is there a realistic chance a competent developer will misunderstand the code and reintroduce the same bug or violate the same constraint?" No → remove it. Yes → keep a short explanation of the reason. Default is zero comments; a comment is an exception, never a documentation mechanism.

## Minimal Scope & Minimal Diff Discipline

- When modifying something (a label, a UI element, a function), change ONLY the specific thing requested. Never refactor unrelated code "while in there" unless explicitly asked.

## Testing Discipline

- **Extract testable logic even when it looks tangled with an untestable layer.** Before concluding something "can't be unit-tested," actively try to pull the real decision logic out of whatever untestable wrapper it's in (a UI lifecycle hook, a gesture handler) into a plain function/method a test can call directly with real inputs. Only treat it as genuinely untestable once that extraction has actually been attempted and doesn't apply.
- **When something is genuinely not unit-testable today** (needs real gesture simulation, a stalled network mount, or render-timing infrastructure the project doesn't have), log it explicitly wherever this project tracks pending test debt, instead of silently skipping it (see `WILES_RULES.md` for where that is here — and for this project's specific rule on *when* the actual test file gets written).
- Every fix for a **data-loss bug** must ship with a red→green regression test once tests are written — one that proves the old code actually caused the loss and the new code doesn't, not just "doesn't throw."
- **Production source code never bends to accommodate a test or UI-automation need.** No test-only branches, hooks, flags, or accommodations may be added to `Sources/` for the sake of making something easier to test or drive from a UI-automation script. If a unit test or UI test needs the source to behave differently than its real, correct behavior, the test is wrong and must be fixed (or rewritten, or deleted if it's testing the wrong thing) — the source never changes to suit it.

## Reflection / Private-API Access Into a Dependency Needs a CI Canary

Any use of reflection or KVC to read non-public state or structure of an external dependency MUST have a CI-level incompatibility detector — preferably a canary test that exercises the exact access path against a real instance of the dependency and fails when it stops resolving (returns `nil`/empty). The point is that a dependency upgrade breaks the build, not production: a silently-failing reflection path degrades to whatever weak fallback exists (a best-effort cleanup that then never runs), leaking the process or resource it was meant to release with no visible signal.

- If a public API on the dependency can do the job, use it instead of reflecting.
- If reflection is genuinely the only way, capture the value once at a known-good moment (right after constructing the dependency's object) and store it, rather than reflecting again later at teardown time.
- The canary test is mandatory as part of any dependency version bump checklist.

## Never Destroy User Data — Fail Loud and Untouched

- A destructive operation (move, delete, overwrite) must never leave the user with less than they started with. If any precondition isn't clearly safe, abort before touching anything — never "clean up" the destination, delete-then-recreate, or perform a partial/irreversible step before the operation is confirmed possible.
- Any function that removes/overwrites a destination "to make room" for a write MUST first verify the destination isn't the source itself, and MUST NOT proceed with the destructive half unless the constructive half is actually going to happen. Prefer erroring out over guessing.

### Destination-Collision Handling Must Be Explicit and Non-Destructive

- Any filesystem operation that writes to a path which may already exist must either (a) auto-pick a free name (e.g. `UniqueFileNaming`), or (b) surface a replace / keep-both / cancel decision to the user. It must never silently overwrite (`replaceItem`), and never delete the destination (`removeItem`) before the constructive step is proven possible.
- Unattended callers (background rules, auto-organization) must take path (a) — there is no user present to prompt.
- Each collision fix ships with the red→green regression test the "Never Destroy User Data" rule mandates: the old code destroys the destination, the new code doesn't.

### Untrusted Archive Entry Names Are Boundary-Checked Before Becoming a Filesystem Path

- Every code path that turns an archive entry name (read from a ZIP central directory, `unzip`/`tar` output, an inspector list, …) into a `URL` you then read, move, or write MUST first reject the name if it contains a `..` path component or is absolute, AND — after building the URL — confirm the resolved path (`resolvingSymlinksInPath()`) is still inside the intended staging/destination directory. Never rely on the extraction tool (`ditto`/`bsdtar`) to sanitize on your behalf, and never compute a *source* path from the raw entry name and then `moveItem` whatever happens to be there.
- The failure this prevents: a crafted archive with an entry named `../../../…/.ssh/id_rsa` (any `..` chain to a real readable file) makes the code relocate an arbitrary file the user can read — SSH keys, credentials, cookie DBs — out of its real location; if the target folder is itself LAN-shared, that then exposes it.
- `ArchiveService.entryEscapesDestination` is the shared check. `ArchiveService.extractArchive` and `ArchiveInspectionService.extractSingleEntrySync` both run it; any third archive-consuming path runs it too.
- Code review: BLOCKING.

### A Destructive Action Is Either Undoable Through the Standard Path, or Warns Explicitly (R4)

- Any action that removes or relocates the user's data MUST either (a) record an undo step through the app's normal undo path (so ⌘Z reverses it), or (b) show explicit copy that it can't be undone that way ("files go to the Trash and can be restored from there; ⌘Z does not undo this", or "this cannot be undone").
- The user's mental model is set by the *normal* path: a plain "Move to Trash" IS ⌘Z-undoable, so any other flow that also says "Move to Trash" (bulk duplicate cleanup, an inline sheet action) must either match that — record a **single grouped undo entry** covering every item (see the batch-undo rule below) — or say up front that it doesn't.
- Reference points: `AutoOrganizationSheet` shows an explicit "no undo" notice; `FileShredderService` always confirms because it bypasses the Trash entirely. `DuplicateCleanerSheetView.trashSelected` records one grouped `.batch` undo for the whole selection; single-file `chmod` in `FilePropertiesSheet` records a `.chmod` undo. Recursive `chmod` still relies on its confirmation dialog. Code-review checklist item; not mechanically detectable.

### Batch Operations Record One Grouped Undo Entry, Never One Per Item

- Any operation acting on a multi-item selection (bulk move, move-to-Trash, cut/copy-paste, batch rename, duplicate cleanup) MUST record **exactly one** undo entry covering every item — never a `for` loop of `recordAction` per item. Accumulate the per-item actions and record them through the grouped-undo primitive (`UndoRedoService.recordActions(_:)` → `UndoActionType.batch`), which degrades to the bare action for a one-item batch.
- Two failures this prevents: (1) `⌘Z` reverting one item at a time, contrary to the platform mental model where a plain multi-file "Move to Trash" is one undo step; (2) the fixed-size undo history (`maxHistoryLimit`) silently dropping the oldest items of a large operation — those become un-undoable with no signal to the user. The cap must count **user actions**, not items.
- The primitive reverts each sub-action independently: a failed item is re-pushed as a retryable grouped entry and reported ("N of M changes could not be undone"), the rest still revert. `UndoRedoService.undoBatch` / `redoBatch` are the reference.
- Code review: BLOCKING for any new call site recording undo for a multi-item action.

### Preflight/Executor Consistency

A batch operation validated by a preflight check MUST be executable to that validated final state regardless of the order its steps run in. Cycles, swaps, and destination collisions among the batch's own members must go through staging / temporary names (or an equivalent mechanism) so no single step fails on a name another step is about to vacate. `BatchRenameService` stages rename cycles through unique hidden temp names.

Code review: BLOCKING.

### A Fallible Staging Step Must Be Inside the Recovery Scope of the Operation It Stages For (R6)

Any fallible staging step that precedes a reversible operation must be inside the operation's recovery scope. A failure during staging must preserve or restore the ability to retry/undo/redo — not just a failure in a later step of the same operation. Concretely: if a multi-step recovery block re-pushes an undo/redo record on failure, the staging call itself must be inside that same `do`/`catch`, never a bare `try` that precedes it — a failure at the very first step of the sequence must not be able to escape the recovery block that every later step is protected by. `UndoRedoService.undoRenamePermutation`/`redoRenamePermutation` calling `BatchRenameService.stagePermutationCycles` before their `do`/`catch` began was the counterexample this rule was written against — a staging failure there silently dropped the undo/redo record with no way to retry.

This also covers a staging loop that iterates several independent groups (one per directory, one per batch member, etc.): a failure partway through must roll back everything staged across *every* group so far, not just the group that was in progress when it failed. Rolling back only the current group and leaving earlier, already-succeeded groups staged under hidden temp names is the same bug — those earlier groups just have their own local `do`/`catch` instead of none at all. `BatchRenameService.stagePermutationCycles` originally rolled back only the failing directory's own staged entries inside a per-group `do`/`catch`, stranding any other directory's files already staged in that same batch; the fix accumulates all staged entries in one dictionary and rolls back the whole dictionary from a single `do`/`catch` wrapping the entire multi-group loop.

Code review: BLOCKING for any new staging/rollback sequence, including one with more than one staging group per call.

### A Cancellable Batch Operation Must Preserve and Finalize Partial Results Already Committed Before Cancellation (R7)

A cancellable batch operation must preserve and finalize partial results already committed before cancellation. Cancellation may stop future work, but must not discard accounting, undo state, or reporting for work already performed. A loop accumulating side effects (undo actions, counters, partial results) across iterations must `break` on `Task.isCancelled` — the specific mechanism matters less than the outcome — and still run its completion/recording code; it must never `return` early and drop everything accumulated so far. `DuplicateCleanerSheetView.trashSelected()` was the counterexample: cancelling mid-batch returned before `recordActions` ran, so files already moved to Trash had zero undo record even though the disk operation had genuinely happened.

The same applies when the cancellation check is `try Task.checkCancellation()` and the loop is inside a `throws` function: `throw`ing out of the loop on cancellation is exactly as destructive as an early `return` — the caller's `catch` sees only an error, never the partial result, even though the loop's own accumulated arrays are sitting right there. `BatchRenameService.renameStagedPreviews` was this rule's second counterexample: cancellation threw out of the whole function, discarding every rename already completed in that batch instead of returning them in a `BatchRenameResult`. Prefer `if Task.isCancelled { break }` over `try Task.checkCancellation()` in any loop whose surrounding function must still return (not throw) a partial result.

Code review: BLOCKING for any new cancellable batch loop that accumulates undo/progress state, whether cancellation is observed via `Task.isCancelled` or `Task.checkCancellation()`.

### A Function Whose Completion Timing Varies by Input Needs an Explicit, Awaitable Completion Contract

When a function is synchronous for some inputs and fire-and-forget/asynchronous for others — with nothing in its signature or return type signaling the difference — a caller that needs to run code dependent on its post-completion state will write code that's correct for the common (synchronous) case and silently wrong for the other. Give such a function one explicit completion contract every caller can rely on (make it genuinely `async`/awaitable for every input, or expose a completion callback/`Task` the caller can attach to) rather than leaving the sync/async distinction implicit in the shape of the input. `AppState.navigateTo` is the example this was found against — synchronous for a local path, fire-and-forget for a `/Volumes/…` path — where `AppState+SmartFolders.runSmartFolder` was written correctly only for the synchronous case and silently raced the asynchronous one.

Code review checklist item when adding a new caller of `navigateTo`/`openItem`, or writing a similarly-shaped mixed-completion function elsewhere — not mechanically lint-detectable.

## Full Rule Self-Audit Before Every Commit

- Before every commit, run the project's validation tooling (build/tests/lint/format — see `WILES_RULES.md` for this project's specific command) **and** perform an explicit self-audit of the diff (staged + unstaged) against the applicable rules in `DEV_RULES.md`, `SWIFT_LANG_RULES.md`, `WILES_RULES.md`, and `WILES_UI_UX_RULES.md` — scoped to the code the diff actually touches, not a full-repo re-audit every time.
- If the work being committed came from an "Architect Mode" task (see above), the self-audit also checks that mode's own bar: was discovery exhaustive, are the new APIs explicit rather than implicit, is the decomposition SRP-clean — not just "does it build and pass lint."
- **State the audit result explicitly before committing** — which areas were checked, and either "clean" or what was fixed. Don't silently skip this and go straight to `git commit`. If a violation is found, fix it in the same commit rather than committing it and fixing later.
- This is the same checklist a `/code-review` pass would apply — running it yourself before committing is what keeps that pass from finding anything.
