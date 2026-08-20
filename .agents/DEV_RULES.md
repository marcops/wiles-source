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

## Minimal Scope & Minimal Diff Discipline

- When modifying something (a label, a UI element, a function), change ONLY the specific thing requested. Never refactor unrelated code "while in there" unless explicitly asked.

## Testing Discipline

- **Extract testable logic even when it looks tangled with an untestable layer.** Before concluding something "can't be unit-tested," actively try to pull the real decision logic out of whatever untestable wrapper it's in (a UI lifecycle hook, a gesture handler) into a plain function/method a test can call directly with real inputs. Only treat it as genuinely untestable once that extraction has actually been attempted and doesn't apply.
- **When something is genuinely not unit-testable today** (needs real gesture simulation, a stalled network mount, or render-timing infrastructure the project doesn't have), log it explicitly wherever this project tracks pending test debt, instead of silently skipping it (see `WILES_RULES.md` for where that is here — and for this project's specific rule on *when* the actual test file gets written).
- Every fix for a **data-loss bug** must ship with a red→green regression test once tests are written — one that proves the old code actually caused the loss and the new code doesn't, not just "doesn't throw."

## Never Destroy User Data — Fail Loud and Untouched

- A destructive operation (move, delete, overwrite) must never leave the user with less than they started with. If any precondition isn't clearly safe, abort before touching anything — never "clean up" the destination, delete-then-recreate, or perform a partial/irreversible step before the operation is confirmed possible.
- Any function that removes/overwrites a destination "to make room" for a write MUST first verify the destination isn't the source itself, and MUST NOT proceed with the destructive half unless the constructive half is actually going to happen. Prefer erroring out over guessing.

## Full Rule Self-Audit Before Every Commit

- Before every commit, run the project's validation tooling (build/tests/lint/format — see `WILES_RULES.md` for this project's specific command) **and** perform an explicit self-audit of the diff (staged + unstaged) against the applicable rules in `DEV_RULES.md`, `SWIFT_LANG_RULES.md`, `WILES_RULES.md`, and `WILES_UI_UX_RULES.md` — scoped to the code the diff actually touches, not a full-repo re-audit every time.
- If the work being committed came from an "Architect Mode" task (see above), the self-audit also checks that mode's own bar: was discovery exhaustive, are the new APIs explicit rather than implicit, is the decomposition SRP-clean — not just "does it build and pass lint."
- **State the audit result explicitly before committing** — which areas were checked, and either "clean" or what was fixed. Don't silently skip this and go straight to `git commit`. If a violation is found, fix it in the same commit rather than committing it and fixing later.
- This is the same checklist a `/code-review` pass would apply — running it yourself before committing is what keeps that pass from finding anything.
