I want a COMPLETE architectural and code review of the project.

IMPORTANT:
- Analyze ONLY source code files.
- Do NOT analyze tests, test files, test mocks, or code exclusively related to tests.
- Skip every file listed in `IGNORAR.md`.
- Do not do a superficial or sampling-only review.
- Review the relevant code files line by line.
- Do not change the code during this step. Only analyze and produce the report.
- At the end, generate a `TODO/ARCHITECTURE_CODE_REVIEW.md` inside the `TODO` folder.

Never consider the review complete until 100% of the relevant code files have been analyzed.

## Goal

I want a review done as if you were simultaneously:

1. Senior/Staff Swift Engineer
2. Software Architect
3. Architecture and design patterns specialist
4. Swift/SwiftUI and performance specialist
5. UI/UX Engineer
6. Product Engineer

I don't want you to simply validate whether the current code is "good".

I want you to try to DISCOVER problems and opportunities I haven't noticed yet.

The current architecture is the project's own architecture. It should be respected as context, but must NOT be considered correct simply because it has already been adopted.

If you believe any current architectural decision is wrong, excessively complex, hard to maintain, or unsuitable for the product, say so explicitly.

## What to look for

Analyze, among other things:

### Code

- DRY
- KISS
- SOLID when actually applicable
- Clean Code
- poorly distributed responsibilities
- unnecessary abstractions
- duplication
- excessively complex code
- methods/classes that are too large
- unnecessary coupling
- unnecessary dependencies
- duplicated state
- scattered logic
- conditions that could be simplified
- inconsistent internal APIs
- naming
- inadequate types
- force unwraps / force casts
- error handling
- edge cases
- impossible or inconsistent states
- race conditions
- concurrency issues
- memory management
- retain cycles
- lifecycle issues
- Swift Concurrency
- MainActor
- Sendable
- async/await
- performance
- unnecessary allocations
- repeated work
- operations that could be lazy
- unnecessary I/O operations
- scalability issues

### Architecture

Critically check:

- separation of responsibilities
- boundaries between components
- dependencies
- direction of dependencies
- coupling
- cohesion
- extensibility
- structural testability (WITHOUT analyzing the tests)
- state management
- persistence
- communication between components
- events
- services
- stores
- models
- views
- view models
- protocols
- abstractions
- composition
- lifecycle
- feature isolation

Also evaluate whether patterns such as:

- Strategy
- Factory
- Adapter
- Coordinator
- Observer
- Repository
- Command
- State
- Dependency Injection
- etc.

would be useful.

BUT do NOT introduce design patterns just because they exist.

A pattern should only be suggested when it solves a real problem.

# Sequence and State Machine Analysis

Don't analyze functions in isolation only.

When an operation depends on multiple functions or components, trace the complete sequence.

Examples:

View → Store → Service → filesystem
View → Process manager → Process → termination callback
Preflight → Executor → Rollback
User input → parser → URL → filesystem
Watcher → debounce → reload → UI
Shared service → View lifecycle → resource

For each sequence, look for inconsistencies between the states assumed by each layer.

Check especially:

- who can call the operation;
- in which state it can be called;
- what happens if it's called twice;
- what happens if it's called during another operation;
- what happens if it fails;
- what happens if it's cancelled;
- what happens if the owner disappears;
- whether callbacks can arrive after termination;
- whether the final state actually matches the operation's outcome.

A finding can live in the interaction between components even if each component looks correct in isolation.


After the local analysis of each file, also do a cross-cutting analysis across related components.

Don't consider a function correct just because its local implementation looks correct.

Trace its callers, callees, shared state, lifecycle, and side effects when necessary to determine its real behavior.


## AVOID OVERENGINEERING

This is a MAIN rule of the review.

I don't want to turn simple code into a complex architecture just to follow theoretical principles.

Always question:

- Does this abstraction actually reduce complexity?
- Is this protocol actually necessary?
- Does this layer actually add value?
- Does this class need to exist?
- Does this pattern solve a real problem?
- Are we building infrastructure for a problem that doesn't exist yet?
- Could the code be significantly simpler?
- Are we abstracting something that will probably never have another implementation?
- Are we creating too much indirection?
- Are we sacrificing readability to gain hypothetical flexibility?

If the current solution is simple and correct, do NOT suggest a change just because a "more sophisticated" architecture exists.

I want to optimize for:

    simplicity
    + correctness
    + maintainability
    + low coupling
    + low bug risk
    + performance
    + future evolution

and NOT for:

    quantity of abstractions
    + quantity of protocols
    + quantity of patterns
    + architecture for architecture's sake

IN OTHER WORDS
    if something is complex and can be made simpler, flag it — the goal is fewer lines, less code, more simplicity, fewer bugs, fewer ifs and corner cases.

## I want discoveries, not just validation

Actively look for things like:

- bugs that haven't been noticed yet
- incorrect behavior in edge cases
- states that can become inconsistent
- paths that can cause crashes
- race conditions
- lifecycle issues
- memory leaks
- performance issues
- code that works today but will probably break as the product evolves
- decisions that will make future features harder
- points where a small change now will avoid a big change later
- responsibilities that should live elsewhere
- code that can be removed
- code that can be consolidated
- code that can be simplified
- abstractions that could disappear
- components that could be combined
- components that should be split apart
- dependencies that can be eliminated
- logic that should be centralized
- logic that should NOT be centralized
- inconsistencies between features
- conventions that aren't being followed
- standardization opportunities
apparently dead code;
APIs with no consumers;
abstractions with no multiple implementations;
unnecessary properties;
unreachable branches.


In Swift

unnecessary public;
internal vs private;
protocols exposed without need;
types that leak implementation abstractions.
@State
@StateObject
@ObservedObject
@Environment
@EnvironmentObject
@Bindable
view identity
body recomputation
reference types inside value views
derived state
view lifecycle.

## Product / business

Also analyze the code from a Product standpoint.

Look for technical decisions that might hinder:

- future features
- product evolution
- UX changes
- behavior changes
- configuration
- functional scalability
- support for new use cases

If you find something worth preparing for now for business reasons, point it out.

However:

Do NOT implement or preemptively recommend infrastructure for hypothetical features without concrete justification.

Don't record purely stylistic differences as findings, except when they affect consistency, readability, maintenance, or risk.

Clearly distinguish:

- current problem
- preventive improvement
- reasonable preparation for the future
- overengineering


# Duplicate Finding Control

If the same problem appears in several files:
- determine whether there is a common architectural cause;

A finding should exist because there is impact on at least one of these:

- correctness;
- risk;
- maintenance;
- complexity;
- performance;
- lifecycle;
- architecture;
- UX/product;
- system evolution.

If the benefit is purely subjective, don't record it.

## Evidence and Confidence

Don't record a purely hypothetical behavior as a BUG.

For each finding, determine the level of evidence:

- CONFIRMED — the code directly demonstrates the problem;
- HIGH CONFIDENCE — the behavior is a clear consequence of the analyzed flow;
- MEDIUM CONFIDENCE — depends on a specific condition not fully demonstrable in the code;
- LOW CONFIDENCE — hypothesis that deserves further investigation.

LOW CONFIDENCE findings should not receive high severity or high ROI.

When possible, describe the execution path that demonstrates the problem.

## Dependency Tracing

When necessary to confirm a finding, trace:

- callers;
- callees;
- references to the symbol;
- state mutations;
- lifecycle;
- owners;
- callbacks;
- delegates;
- publishers/subscribers;
- notifications;
- related tasks.

Don't do indiscriminate tracing of the whole project for every symbol.

Expand the analysis only when necessary to understand the behavior or confirm the impact of a finding.

## UI / UX

Also analyze:

- loading states
- empty states
- error states
- visual feedback
- inconsistent states
- unexpected behavior
- destructive actions
- confirmations
- affordances
- navigation
- accessibility
- consistency
- sheet/dialog behavior
- feedback after operations
- error UX
- long-operation UX
- impossible UI states

Look for problems that might not be obvious just by looking at the architecture.
I want discoveries, not just validation

## Invariants

For components with significant state, identify their invariants.

Examples:

- if A exists, B must also exist;
- if an operation is `running`, exactly one owner exists;
- if the preflight approved an operation, the executor must be able to execute it;
- if a resource is `active`, its lifecycle owner must still exist;
- if a View observes a given state, that state must represent the corresponding source of truth.

Look for paths capable of breaking these invariants.

When a finding depends on an invariant, explicitly describe:

`Invariant → path that breaks it → resulting state → impact`.

## Idempotency and Repeated Operations

For lifecycle, persistence, filesystem, network, and state management operations, check:

- what happens if the operation is called twice;
- whether `start()` can be called twice;
- whether `stop()` can be called before `start()`;
- whether `cancel()` can be called twice;
- whether a completed operation can be repeated;
- whether callbacks can arrive duplicated;
- whether retries can re-execute side effects.

Identify operations that should be idempotent but aren't.

## Cancellation

For all relevant asynchronous code, analyze:

- `Task` cancellation propagation;
- `Task.isCancelled` / `checkCancellation()`;
- orphaned tasks;
- detached tasks;
- operations that continue after the View disappears;
- callbacks after cancellation;
- cleanup after cancellation;
- duplicated tasks;
- possibility of concurrent operations on the same resource.

Don't consider an operation cancellable just because it returns `Task` or uses `async/await`.

Check whether cancellation actually stops or invalidates the work.

## High-Frequency Events

For watchers, notifications, keyboard events, scroll, drag, typing, and other sources of frequent events, analyze:

- debounce;
- throttle;
- coalescing;
- deduplication;
- queues;
- backpressure;
- redundant work;
- stale events;
- MainActor processing.

Check whether stale events keep being processed when their result is no longer relevant.

Look especially for pipelines where:

`event → state mutation → render → work`

is executed repeatedly when it could be coalesced.

## Simplification and Code Reduction

Actively look for opportunities to remove complexity.

Consider:

- eliminating abstractions;
- removing unnecessary protocols;
- eliminating wrappers;
- combining types that have no independent responsibility;
- removing redundant state;
- replacing unnecessary state machines with simple types/enums;
- eliminating redundant branches;
- replacing excessively indirect pipelines with direct calls;
- removing duplicated configuration;
- reducing the number of layers;
- removing dead code;
- centralizing only when it actually reduces duplication;
- replacing custom mechanisms with native APIs when that reduces complexity.

For each simplification proposal, also estimate:

- potentially removable lines/layers;
- number of affected components;
- risk of the change;
- whether the simplification reduces complexity or just shifts it.

Don't propose a simplification if it just moves the complexity elsewhere.

## Complexity Budget

When evaluating an abstraction, consider the total complexity introduced:

- number of types;
- number of protocols;
- number of layers;
- amount of indirection;
- amount of state;
- amount of lifecycle;
- number of branches;
- number of configuration points.

A solution that reduces duplication but significantly increases structural complexity should be critically evaluated.

Prefer the solution with the lowest total complexity that preserves correctness, maintainability, and evolvability.

## My current architecture

Don't assume my architecture is correct.

Use it as context.

If you find something you believe should be different:

1. explain the problem;
2. explain why the current architecture is not ideal;
3. explain the alternative;
4. explain the cost/migration;
5. say whether it's worth doing now or later.

Don't do an architectural rewrite simply out of personal preference.

## New rules

Don't limit yourself to the rules above.

If during the review you identify an engineering rule that should exist in the project, present it as:

SUGGESTED NEW RULE

Explain:

- what the rule is;
- what problem it prevents;
- examples found in the project;
- whether it should become a guideline, code review rule, or lint rule.

## LINT

At the end, do a specific analysis looking for automation opportunities.

Check whether any of the discoveries can become a Lint rule.

For each candidate, provide:

- proposed rule;
- problem it prevents;
- example from the current code;
- whether it can be detected automatically;
- whether it should be Regex, a SwiftLint custom rule, or another approach;
- risk of false positives;
- expected benefit.

If there's a simple rule that could be implemented with Regex and that's genuinely useful, propose it.

Do NOT create lint rules just to create them.

If any of them can produce a false positive, we do NOT want it.
IN OTHER WORDS, WE DO NOT WANT HEURISTICS THAT CAN PRODUCE FALSE POSITIVES. IT HAS TO BE 100% ASSERTIVE.

## IGNORAR.md

There are files in `IGNORAR.md` that are deliberately simple and don't need to be evaluated.

Skip those files.

During the review, if you find other files that clearly don't need future review because they're trivial, repetitive, generated, or add no architectural value, suggest adding them to `IGNORAR.md`.

Don't add them automatically without justifying it in the report.

## Classification of findings

For each problem found, classify:

CRITICAL (C)
- can cause serious bugs, state corruption, crashes, data loss, or major architectural problems.

HIGH (H)
- important problem that should be fixed.

MEDIUM (M)
- relevant improvement to architecture, maintenance, performance, or quality.

LOW (L)
- small or quality improvement.

SUGGESTION (S)
- future idea, optional improvement, or possible evolution.

ARCHITECTURAL CONCERN (A)
- structural decision that deserves reconsideration.

OVERENGINEERING (O)
- abstraction, complexity, or architecture that could be simplified.

BUG (B)
- potentially incorrect behavior.

PERFORMANCE (P)
- concrete opportunity to improve performance.

PRODUCT/UX (U)
- problem or opportunity related to experience or product.


## Cost × Benefit / ROI

For each suggested improvement, estimate:

- Impact: 0–100
- Risk reduction: 0–100
- Maintenance benefit: 0–100
- Performance benefit: 0–100
- Simplicity benefit: 0–100
- Effort: 0–100
- Change risk: 0–100

Calculate:

VALUE =
(Impact × 0.30) +
(Risk reduction × 0.25) +
(Maintenance benefit × 0.20) +
(Performance benefit × 0.10) +
(Simplicity benefit × 0.15)

COST =
(Effort × 0.70) +
(Change risk × 0.30)

ROI = VALUE / COST


When there isn't enough evidence to estimate a given factor, mark it as "UNKNOWN" instead of inventing precision.

The estimate should be based on the concrete impact observed in the code, not on the number of principles or rules violated.

Don't recommend an improvement just because it's technically correct.
The improvement must show a benefit proportional to the cost and risk of the change.


## For each discovery

Include:

- Severity
- Category
- File
- relevant symbol/method/class
- problem
- why it's a problem
- impact
- suggested solution
- fix complexity
- ROI

When possible, include a short explanation of the code involved.

Don't make vague suggestions like "improve architecture".

I want to know EXACTLY:

"what's wrong"
→ "why it's wrong"
→ "what to do"
→ "what benefit it brings"


## Final result

Create a report at:

`TODO/ARCHITECTURE_CODE_REVIEW.md`

The report must contain at least:

# Architecture & Code Review

## Findings by ID

The ID must be composed of severity, impact, and ROI
e.g. BA-127 (roi *100=) (bug high 1.27)
or SM-089 (suggestion medium 0.89)
or for example
or CL-290 (critical low 2.9)

**## Finding ID**

Each finding must receive an ID in the format:

`[SEVERITY][IMPACT]-[ROI × 100]`

Where:

Severity:
- C = Critical
- H = High
- M = Medium
- L = Low
- S = Suggestion

Impact:
- C = Critical
- H = High
- M = Medium
- L = Low

Examples:

- `CH-290` = Critical severity / High impact / ROI 2.90
- `HM-142` = High severity / Medium impact / ROI 1.42
- `SL-085` = Suggestion severity / Low impact / ROI 0.85

ROI must be rounded to two decimal places and multiplied by 100 to form the ID's numeric suffix.

The ID must remain stable throughout the review, even if the order of findings changes.

Findings would look, FOR EXAMPLE, like this:

### [SL-242] Duplication of `ThumbnailService.maxDimension` and `FileItem.highResIconSize`
- ROI: 2.42 (Strong candidate)
- LOW / DRY / magic number
- Files: `Services/ThumbnailService.swift`, `Models/FileItem.swift`
- Problem: the same value and purpose are defined in two places.
- Solution: centralize into a single shared token.
- Complexity: low.

# NOT WORTH
[SL-085] LOW / DRY — duplication of X in A.swift and B.swift — ROI 0.85.
[SM-062] MEDIUM / SIMPLIFICATION — X could be simplified — ROI 0.62.

The NOT WORTH FILTER is:

LOW, SUGGESTION, COSMETIC, UI UX + ROI < 1.00 → NOT WORTH
MEDIUM + ROI < 0.70 → NOT WORTH
All other discoveries remain in the main list.

Items in NOT WORTH must be summarized in a SINGLE LINE each.
IN OTHER WORDS, THEY DO NOT APPEAR IN FULL IN FINDINGS BY ID.

Do not include the full details of these items.
Do not create additional sections, consolidations, or groupings beyond NOT WORTH.

# NOT WORTH — STRICT DISCARD RULE

`NOT WORTH` does NOT mean "low ROI, therefore ignore".

Before putting ANY finding in `NOT WORTH`, you must perform this check:

### 1. Safety Gate

If the finding involves ANY of the items below, it CANNOT be placed in `NOT WORTH`, regardless of ROI:

- data corruption;
- data loss;
- persisted state loss;
- crash;
- resource leak;
- process leak;
- infinite loop;
- deadlock;
- race condition;
- security issue;
- incorrect behavior observable by the user;
- an operation that can fail after having been declared valid;
- inconsistent state;
- filesystem corruption;
- orphaned temp file after a crash/failure;
- an Undo/Redo operation that might not revert correctly;
- incorrect lifecycle;
- callback after the owner/resource has been torn down;
- an operation that can leave resources or state in an invalid condition.

The presence of any of these problems OVERRIDES the ROI filter.

### 2. Only apply the ROI filter afterward

After the Safety Gate:

- LOW + ROI < 1.00 → `NOT WORTH`
- MEDIUM + ROI < 0.70 → `NOT WORTH`

All others remain in `Findings by ID`.

### 3. Don't misclassify the type of problem

Don't classify as `PERFORMANCE`, `COSMETIC`, `DRY`, or `EDGE CASE` a finding whose final effect is:

- incorrect operation;
- inconsistent state;
- data loss;
- Undo failure;
- inconsistent filesystem;
- incorrect lifecycle.

Classify by the REAL IMPACT of the behavior.

Example:

`crash during operation → temp file becomes orphaned`

is NOT just:

`LOW / EDGE`

It is:

`LOW / BUG / filesystem recovery`

Another example:

`trashItem doesn't return a URL → Undo receives the wrong URL → Undo fails`

is NOT just:

`LOW / EDGE`

It is:

`LOW / BUG / UX`

Another example:

`sanitizer accepts a name <= 255 characters → filesystem rejects > 255 bytes`

is NOT just:

`LOW / PERFORMANCE`

It is:

`LOW / BUG / filesystem`

### 4. Discrepancy between ROI and severity

When a finding protected by the Safety Gate has a low ROI, keep it in the main list and explain:

> Low ROI due to low frequency/probability, but not discarded because the behavior can produce [concrete effect].

Never artificially inflate the ROI to justify keeping it.

### 5. Fundamental rule

`NOT WORTH` is reserved exclusively for improvements that are:

- not critical;
- not incorrect;
- not destructive;
- not causing inconsistency;
- not related to incorrect lifecycle;
- not causing a leak;
- not causing a crash;
- not causing data/state loss;
- and whose benefit doesn't justify the cost of the fix.

If in doubt between `NOT WORTH` and `Findings by ID`,
keep it in `NOT WORTH`.

# ROI Discipline

Don't artificially inflate the ROI just because a problem is technically interesting.

A performance finding should only receive a high performance benefit if there's a plausibly frequent or costly execution path.

An edge-case finding should only receive high impact if the code demonstrates that the state can actually occur.

If impact, frequency, or cost are uncertain, use UNKNOWN.

Don't use architectural principles in isolation as justification for raising Impact or Risk Reduction.

## Suggested New Engineering Rules

## Suggested Lint Rules

## Files That Could Be Added to IGNORAR.md

## PROJECT NOTE

And I want a note for the project:
Global
architecture
code
product
and any other you think makes sense


# FINAL RULE

I don't want a complacent review.

Don't assume the code is correct just because it compiles.

Don't assume the architecture is correct just because it was deliberately designed.

Don't introduce complexity without real benefit.

Don't look only for rule violations.

Also look for what is NOT explicitly forbidden, but that could be better.

The goal is to find problems a developer wouldn't normally notice in a superficial review, and leave the project:

- simpler
- safer
- more predictable
- more performant
- easier to evolve
- easier to maintain
- less bug-prone

Without overengineering.

IMPORTANT RULE:
DO NOT GENERATE THE FILE AT THE END; APPEND TO IT AS YOU EVALUATE
As you go, report the % progress in the chat
with how many high, medium, low, etc. were found


If you considered ignoring an item because it has a comment, still include this finding with the item's full details (all properties, ROI, etc.)
but in a section at the END:
FINDINGS skipped by comments in the SOURCE CODE

Flickers are serious, so even if one would be not worth, put flickers in a separate, dedicated list.
