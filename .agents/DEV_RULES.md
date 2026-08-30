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

### A Destructive Action Is Either Undoable Through the Standard Path, or Warns Explicitly (R4)

- Any action that removes or relocates the user's data MUST either (a) record an undo step through the app's normal undo path (so ⌘Z reverses it), or (b) show explicit copy that it can't be undone that way ("files go to the Trash and can be restored from there; ⌘Z does not undo this", or "this cannot be undone").
- The user's mental model is set by the *normal* path: a plain "Move to Trash" IS ⌘Z-undoable, so any other flow that also says "Move to Trash" (bulk duplicate cleanup, an inline sheet action) must either match that — record `.trash` undo entries per item — or say up front that it doesn't.
- Reference points: `AutoOrganizationSheet` shows an explicit "no undo" notice; `FileShredderService` always confirms because it bypasses the Trash entirely. `DuplicateCleanerSheetView.trashSelected` now records a `.trash` undo per item; single-file `chmod` in `FilePropertiesSheet` records a `.chmod` undo. Recursive `chmod` still relies on its confirmation dialog. Code-review checklist item; not mechanically detectable.

### Preflight/Executor Consistency

A batch operation validated by a preflight check MUST be executable to that validated final state regardless of the order its steps run in. Cycles, swaps, and destination collisions among the batch's own members must go through staging / temporary names (or an equivalent mechanism) so no single step fails on a name another step is about to vacate. `BatchRenameService` stages rename cycles through unique hidden temp names.

Code review: BLOCKING.

## Full Rule Self-Audit Before Every Commit

- Before every commit, run the project's validation tooling (build/tests/lint/format — see `WILES_RULES.md` for this project's specific command) **and** perform an explicit self-audit of the diff (staged + unstaged) against the applicable rules in `DEV_RULES.md`, `SWIFT_LANG_RULES.md`, `WILES_RULES.md`, and `WILES_UI_UX_RULES.md` — scoped to the code the diff actually touches, not a full-repo re-audit every time.
- If the work being committed came from an "Architect Mode" task (see above), the self-audit also checks that mode's own bar: was discovery exhaustive, are the new APIs explicit rather than implicit, is the decomposition SRP-clean — not just "does it build and pass lint."
- **State the audit result explicitly before committing** — which areas were checked, and either "clean" or what was fixed. Don't silently skip this and go straight to `git commit`. If a violation is found, fix it in the same commit rather than committing it and fixing later.
- This is the same checklist a `/code-review` pass would apply — running it yourself before committing is what keeps that pass from finding anything.
