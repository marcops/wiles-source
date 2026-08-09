# AGENTS.md - Senior Apple Swift Architect Rules & Guidelines for Wiles

## 0. ABSOLUTE COMPLIANCE (READ THIS FIRST)
- **YOU MUST ALWAYS RESPECT AND FOLLOW THESE RULES EXACTLY.** 
- **NUNCA ENTREGAR CÓDIGO SEM SEGUIR AS REGRAS.** (NEVER DELIVER CODE WITHOUT FOLLOWING THE RULES).
- **ALWAYS DISTRUST ASSUMPTIONS & INSPECT AUTHORITATIVE SOURCE DEFINITIONS**: Never guess property names, method signatures, or initializers. Always inspect source files directly with `view_file` or `grep_search` to catch implementation gaps and edge cases.
- These are not suggestions; they are strict constraints. Before writing any code or making any architectural decisions, you must cross-check your plan against these rules (especially regarding Zero Hardcoded Strings, No Magic Numbers, and Native APIs). Failure to comply is a critical error.

## 1. Core Architectural Principles (KISS, YAGNI, DRY, SOLID)
- **KISS (Keep It Simple, Stupid)**: Prefer straightforward, clean SwiftUI state management over over-engineered abstractions or unnecessary layers. Write clear, maintainable Swift code.
- **YAGNI (You Aren't Gonna Need It)**: Build features strictly for concrete requirements. Avoid speculative code or unused generic wrappers.
- **DRY (Don't Repeat Yourself)**: Never duplicate context menus, selection handlers, drag & drop handlers (`.fileItemInteractions`), hover highlighting (`.hoverHighlight`), icon rendering (`FileItemIconView`), or empty state indicators (`EmptyDirectoryView`) across `FileGridView`, `FileListView`, `FileColumnView`, and `SidebarView`. Always use shared SwiftUI ViewModifiers and View Composition components.
- **Single Responsibility Principle (SRP)**: Keep Views focused on layout declaration, Services (`FileSystemService`, `LocalizationService`, `ZipArchiveService`) focused on system logic, and `AppState` focused on application state.
- **Dedicated Feature Service Classes**: Each domain feature or system subsystem MUST reside in its own dedicated, isolated Swift service class file (e.g. `Sources/Wiles/Services/ZipArchiveService.swift`). Never bloat existing service files with unrelated feature logic.
- **No Inline Helper Types**: Never declare a standalone `enum`/`struct` (constants, status codes, options, etc.) inside the same file as an unrelated class/service just because it's used there. It gets its own file in the proper folder (`Constants/`, or a dedicated `Type/Type+Extra.swift` group) — same rule as `AppState/AppState+Navigation.swift`, `Services/FileSystem/FileSystemService.swift`, etc.
- **One Type Per File**: Never declare more than one top-level `enum`/`struct`/`class`/`protocol` in the same Swift file, even if both are small constant/token namespaces (e.g. `KeyCode` and `IconSizeToken`). Each gets its own file named after the type.
- **Composition over Inheritance**: Prefer SwiftUI View Composition, struct values, extensions, and protocol conformance over deep class hierarchies.
- **No Inline Compound Conditions**: Any `if`/`guard` combining 3 or more terms (`&&`/`||`/chained comparisons) MUST be extracted into a separate, well-named comparison function or computed property (e.g. `if isEligibleForBulkDelete(...)` instead of `if x || y || z`) instead of left as an inline boolean chain.

## 2. 100% Native macOS & Proactive Performance Guardrails
- **100% Native macOS APIs**: The application MUST rely strictly on native Apple frameworks (AppKit, SwiftUI, Foundation, `AppleArchive`, native Apple binaries like `ditto`, `NSWorkspace`, `NSPasteboard`). Zero third-party dependencies or non-native wrappers.
- **Maximum Performance & UX Warning**: The application MUST remain blazingly fast and lightweight. ALWAYS warn the user proactively if a requested feature, architectural approach, or disk I/O pattern could slow down the application, freeze the UI, or degrade user experience. Always propose high-performance native alternatives.

## 3. Advanced Swift Data & Code Patterns
- **Value Types First (`struct` & `enum`)**: Default to immutable `struct` and `enum` value types for data models, file items, and state snapshots to eliminate reference mutations. Use `final class` only for `@Observable` state singletons or AppKit lifecycle wrappers.
- **Protocol-Driven Service Abstraction**: Decouple low-level system operations (e.g., `FileManager`, `NSWorkspace`, pasteboards) behind service protocols (`FileSystemServiceProtocol`) for clean isolation and unit testing.
- **Explicit Error Handling**: Never swallow disk I/O or system errors with silent `try?` blocks without logging or user feedback. Always handle errors explicitly using Swift `Result` or `throw` with localized messages.
- **Functional Data Pipelines**: Prefer declarative functional transformations (`map`, `compactMap`, `filter`, `reduce`) over imperative mutating loops for data processing.
- **View Body Decomposition**: Any SwiftUI `body` property or component layout exceeding 30 lines MUST be decomposed into smaller sub-views or `@ViewBuilder` helper properties.
- **Defensive Lifecycle & Resource Management**: Ensure AppKit event monitors (`NSEvent.addLocalMonitor`), timers, and NotificationCenter observers are explicitly removed/invalidated in `deinit` or `onDisappear`.

## 4. Swift Concurrency & Performance Guidelines
- **Main Thread Safety (@MainActor)**: Perform heavy file system scans and disk I/O asynchronously off the main thread, dispatching state updates safely to `@MainActor`.
- **Memory & Retain Cycle Safety**: Use `[weak self]` in AppKit event monitors and long-lived closures to prevent memory leaks.
- **Modern Swift State Observation**: Utilize Swift 5.9+ `@Observable` observation for fine-grained view re-rendering efficiency.

## 5. Strict Localization (i18n & macOS Detection)
- **Zero Hardcoded User-Facing Text**: Never hardcode user-facing text, menu labels, button titles, or status strings directly in SwiftUI views or models.
- **Centralized Localization**: All strings MUST use `LocalizationService` / `appState.tr(.key)` supporting automatic macOS system language detection (English, Portuguese, Spanish, French, German) with user preference override.

## 6. No Magic Numbers or Unnamed Constants
- **Named Tokens & Enums**: Never use raw magic numbers (e.g. key codes like 51, 117, 36, 24, 69, 27, 44, 29, 30), arbitrary multipliers, or unexplained static offsets.
- Always define named constants, enums (e.g. `KeyCode.backspace`, `LayoutTokens.columnSizeWidth`), or compute values dynamically from container bounds.

## 7. Maximum Function Length (< 25 Lines)
- **Function & Closure Modularization**: Inline closures and helper functions MUST NOT exceed 25 lines of code.
- Subdivide complex logic into focused, single-responsibility private helper methods.

## 8. Complete State Persistence
- **Every User Action Must Be Persisted**: Every UI preference or state change (e.g., status bar visibility, icon size, view mode, sidebar mode, shortcut mode, section collapse states for `FAVORITES`, `MAC`, `RECENTS`, `DEVICES`, `DIRECTORY TREE`, expanded folder paths, and language preference) MUST be saved to `UserDefaults`.
- On application launch, all UI elements must restore their exact previous state.

## 9. macOS Human Interface Guidelines (HIG) Integration
- Merge View menu commands directly into native macOS system menus using `CommandGroup(after: .sidebar)` in `WilesApp.swift` instead of `CommandMenu("View")`, preventing duplicate menu items in the macOS menu bar.

## 10. Communication & Commit Discipline
- **Git Commits in English**: All `git commit` messages MUST be written in English using Conventional Commits format (e.g., `feat: ...`, `fix: ...`, `refactor: ...`).
- **Agent Responses ALWAYS in English**: All agent responses to the user MUST be written strictly in English under all circumstances. NEVER reply in Portuguese or any other language, even when the user prompts in Portuguese.
- **Single-Call Pipeline Execution**: ALWAYS use `./scripts/push_and_relaunch.sh "<commit message>"` to build, sign, relaunch, commit, and push in **1 single command invocation** to minimize tool calls and token usage.
- **Test Timing Discipline**: Only run automated tests right before executing a release packaging build. NEVER run test suites during active coding iterations.

## 11. Repository Architecture & Public/Private Separation
- **`marcops/wiles` (PUBLIC REPOSITORY)**: Contains public Homebrew cask formulas (`Casks/wiles.rb`), public release assets (`releases/wiles-vX.Y.Z.dmg`, `releases/wiles-vX.Y.Z.zip`), documentation, and public issue tracking. All Homebrew cask URLs MUST point exclusively to this public repository (`https://raw.githubusercontent.com/marcops/wiles/main/...`).
- **`marcops/wiles-source` (PRIVATE REPOSITORY)**: Contains internal Swift source code. NEVER reference private URLs (`wiles-source`) in public Homebrew formulas or public documentation.

## 12. Automated Homebrew & Release Packaging Protocol
- **Zip Packaging Requirement**: ALWAYS use `/usr/bin/zip -r -y dist/wiles-vX.Y.Z.zip Wiles.app` to ensure the root `Wiles.app/` folder is preserved inside the archive. Never use `ditto` directly on `Wiles.app` for Homebrew releases as it strips the root folder.
- **CDN Cache Busting (CRITICAL)**: When updating `Casks/wiles.rb`, the `url` MUST use the **exact git commit SHA** where the `.zip` was pushed (e.g., `url "https://raw.githubusercontent.com/marcops/wiles/<COMMIT_SHA>/releases/wiles-v#{version}.zip"`). Never use `main` in the URL, as GitHub's Fastly CDN will cache the old binary and cause a Homebrew SHA256 mismatch error.
- **Synchronous Build & Version Verification Guardrail (CRITICAL)**:
  - ALWAYS wait for `swift build -c release` to finish 100% synchronously BEFORE running any copy, codesign, or zip commands. NEVER copy binary assets while a background build task is still running.
  - ALWAYS update `CFBundleShortVersionString` and `CFBundleVersion` in `Wiles.app/Contents/Info.plist` to match the target release version (`vX.Y.Z`).
  - ALWAYS run `strings Wiles.app/Contents/MacOS/Wiles | grep "X.Y.Z"` to verify the binary version BEFORE packaging.
- **SHA256 Verification Checklist**:
  1. Build release binary `swift build -c release` and wait for completion.
  2. Update `Wiles.app/Contents/Info.plist` version strings to `X.Y.Z`.
  3. Copy binary and resources to `Wiles.app`:
     - `cp .build/arm64-apple-macosx/release/Wiles Wiles.app/Contents/MacOS/`
     - `cp -r .build/arm64-apple-macosx/release/Wiles_Wiles.bundle Wiles.app/Contents/Resources/`
  4. Verify compiled binary version: `strings Wiles.app/Contents/MacOS/Wiles | grep "X.Y.Z"`.
  5. Validate bundle exists: `find Wiles.app -name "*.bundle"` (Must return `Wiles.app/Contents/Resources/Wiles_Wiles.bundle`).
  6. Sign `Wiles.app` (e.g., `codesign -f -s - Wiles.app`).
  7. Package DMG `hdiutil create -volname "Wiles" -srcfolder Wiles.app -ov -format UDZO releases/wiles-vX.Y.Z.dmg`.
  8. Package ZIP `/usr/bin/zip -r -y dist/wiles-vX.Y.Z.zip Wiles.app`.
  9. Compute `shasum -a 256 dist/wiles-vX.Y.Z.zip`.
  10. Copy ZIP & DMG to public tap repo `marcops/wiles/releases/`.
  11. Push binaries to public repo first and get the exact commit SHA.
  12. Update `Casks/wiles.rb` version, SHA256, and URL with the exact commit SHA.
  13. Push the Cask update to public repo and verify live with `curl` before declaring completion.


## 13. Generic README Documentation
- **Never Hardcode Versions in README**: The public `README.md` must remain completely generic across versions. Never hardcode version numbers (e.g. `v0.0.5`) in download links, titles, or release notes links. Always use terms like "Latest Release" and point to `releases/latest` or `RELEASE_NOTES.md`.

## 14. Zero Hardcoded Paths & Always Use Temporary Directory
- **Never Hardcode User-Specific Absolute Paths or Raw `/tmp` Strings**: Never hardcode absolute user-specific directory paths (e.g., `/Users/marco/...`) or raw string literals like `"/tmp"` in test files.
- **Always Use `NSTemporaryDirectory()`**: Every temporary folder, dummy URL, or mocked file path MUST be created dynamically using `URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(...)`.

## 15. Minimal Scope & Minimal Diff Discipline
- **Minimal Code Changes**: When modifying text, labels, or UI elements (e.g., sidebar names), change ONLY the specific component or translation key requested by the user. NEVER refactor unrelated helper functions, path bar logic, or system path matching unless explicitly requested.
- **Dedicated UI Keys**: Create dedicated translation keys (e.g., `sidebarTrash`, `sidebarDocuments`) when custom localized text is required for specific UI components, preserving underlying path matching logic intact.

## 16. Strict 1-to-1 Test File Organization Protocol
- **Strict 1-to-1 File Matching**: Every model file in `Sources/Wiles/Models/` MUST have its own dedicated test file in `Tests/WilesTests/Models/<ModelName>Tests.swift`. Every feature in `Sources/Wiles/Features/` MUST have its own dedicated test file in `Tests/WilesTests/Features/<FeatureName>Tests.swift`.
- **Zero Monolithic Coverage Files**: NEVER bundle tests for multiple models, features, or UI sheets into a single aggregated coverage file. Always create individual, isolated test files matching each domain source file.

## 17. Strict Test Isolation & Zero Side-Effects
- **No Shared State Assumptions**: Tests must never assume a shared singleton (e.g., `LocalHttpServerService.shared`) is in a specific initial state. Always query current state or restore initial state defensively in a `defer` block.
- **Zero Real Config Contamination**: Tests must never mutate real user persistence (`UserDefaults.standard`, saved smart folders list, rule lists) directly without isolating keys or restoring original state inside a guaranteed `defer` block.

## 18. Strict UI Test Verification Standards
- **No Silent Optional Clicks**: Never hide interaction checks behind unasserted `if element.exists { element.click() }` blocks. Always assert or explicitly verify element presence.
- **No Meaningless `XCTAssertNotNil` on XCUIElement Queries**: XCUIElement queries (`app.buttons["id"]`) always return non-nil query proxies. Never assert `XCTAssertNotNil(element)` to check visibility — ALWAYS evaluate `element.exists` or `element.waitForExistence(timeout:)`.
- **Target Registration Guarantee**: All UI test files in `Tests/WilesUITests/` MUST be registered in `Package.swift` and executed during automated test runs.

## 19. Mandatory 100% Centralized Localization & VoiceOver Accessibility Standard
- **Zero Hardcoded User-Facing Text**: NEVER hardcode string literals for UI titles, button labels, tooltips (`.help`), status indicators, accessibility labels (`.accessibilityLabel`), hints (`.accessibilityHint`), or VoiceOver values (`.accessibilityValue`).
- **Strict Centralized Localization (`appState.tr(.key)`)**: Every single user-facing string MUST be retrieved via `appState.tr(.key)` backed by `LocalizationService`.
- **Mandatory VoiceOver Accessibility**: Every interactive UI element (buttons, table rows, grid cards, toolbar controls, list items) MUST be decorated with `.accessibilityLabel(...)`, `.accessibilityHint(...)`, `.accessibilityAddTraits(...)`, and `.accessibilityValue(...)` using localized `appState.tr(...)` strings.

## 20. Strict File URL Normalization
- **Never compare raw URL or `String` paths directly using `==`** when either side may originate from user input, `UserDefaults`, or a different code path than the other side. Always resolve both sides via `.standardizedFileURL` first. macOS paths can have trailing slashes, APFS volume prefixing, or symlink variations that point to the exact same physical directory. (Comparing two `FileItem.url` values that both came from the same `contentsOfDirectory` call is fine as-is — they're already canonical.)

## 21. No Synchronous Disk I/O on @MainActor for Non-Local Paths (Anti-Beachball Rule)
- **Local paths may check `FileManager` synchronously** (e.g. `fileExists(atPath:)` on a path under the user's home/boot volume resolves in microseconds — dispatching this to a background task adds latency and complexity for zero real benefit).
- **Anything under `/Volumes/` (SMB/FTP/SFTP shares, external drives) MUST run its `FileManager` calls off `@MainActor`** — hop to `Task.detached`, then apply the result back on `@MainActor`. A stalled or unreachable network mount can block a synchronous call for many seconds, freezing the whole UI. Real example fixed: `AppState.navigateTo()` used to call `fileExists(atPath:)` synchronously for every navigation, including into network shares — see `AppState+Navigation.swift`.

## 22. Explicit Animation Boundaries
- **Never attach `.animation(_:value:)` or wrap `withAnimation` around a high-level container view** (a root `ZStack`, the outer `ScrollView`, or anything that re-renders when a large folder loads). Attach animation only to the specific leaf element changing (an icon, a selection border, a single scroll target) so a big directory load can't accidentally trigger an animated full-tree layout recalculation.

## 23. Prohibit AnyView
- **No `AnyView`, ever.** It erases SwiftUI's structural identity and forces aggressive re-rendering. Use `@ViewBuilder` with `if`/`else` or `switch` to resolve dynamic view types while preserving `some View`.

## 24. UserDefaults Payload Limits
- **`UserDefaults.standard` is for lightweight toggles, enums, numbers, and small bounded arrays/JSON only** (e.g. `listColumnStates`, `AutoOrganizationRule` list) — never for large collections or a full directory listing. `UserDefaults` reads/writes are synchronous and can block the main thread if the payload is heavy. Directory-scale caching belongs in an in-memory service (see `DirectoryCacheService`), not `UserDefaults`.

## 25. Explicit View Identity Reset on Full Dataset Replacement
- **When a view's entire backing dataset is replaced wholesale** (e.g. navigating to a different directory with a completely different 1,000+ item list), attach `.id(directoryURL)` to the container holding that content. This forces SwiftUI to destroy and recreate the view tree instantly instead of diffing thousands of old rows against thousands of new ones. See `FileListView`/`FileGridView`, which key their content `Group` on `appState.navigation.currentURL`.

## 26. Defensive Memory Bounding for Caches
- **Never back an in-memory cache (directory listings, thumbnails, images) with an unbounded dictionary.** Use `NSCache` with an explicit `countLimit` and `totalCostLimit` (see `DirectoryCacheService`: 50 entries / 30 MB) so heavy navigation can't silently balloon RAM usage.

## 27. Scope GeometryReader to Preference-Key Frame Extraction, Not All Layout
- **When `GeometryReader` exists only to read a child's frame for a `PreferenceKey`** (e.g. `ListCellFrameKey`/`CellFrameKey` row-frame tracking for marquee-selection hit testing), wrap it in `.background(GeometryReader { ... }.preference(...))` so it doesn't participate in layout sizing — see the row-frame extraction in `FileListView`/`FileGridView`.
- This does **not** mean "never use `GeometryReader` as a structural root" — reading a container's available width to drive adaptive sizing (grid column count, breadcrumb truncation, sidebar-width tracking) is a legitimate, necessary use and several views rely on it (`FileListView`, `FileGridView`, `PathBarView`). Don't flag or "fix" that pattern; only the preference-key-extraction case must be background-scoped.

## 28. Red-Green: Tests Before the Fix, Not After
- **When fixing a bug or implementing a testable unit of logic, write the test first, run it, and confirm it actually fails (red) before writing the fix.** Only then write the minimal code to make it pass (green). A test added after the fix already exists never proves it would have caught the bug — it's not verified to fail against the old code.
- **Every non-cosmetic behavior change in this session must have a corresponding unit test** in `Tests/WilesTests/` before it's considered done — not just "the app still builds and existing tests still pass." If a fix isn't practically unit-testable (a real gesture-drag interaction, an actual stalled network mount), say so explicitly instead of silently skipping coverage.
- This applies to Claude/agent-driven changes just as much as human-written ones — no exception for "it's just a small fix."
- **When something genuinely isn't unit-testable today** (needs real gesture simulation, a stalled network mount, or SwiftUI render-timing infrastructure this project doesn't have), it MUST be logged in `UI_TEST_BACKLOG.md` at the repo root with what's missing and why — not silently skipped. Pull an item off that list and write the real test the moment the missing infrastructure exists.

## 29. Pre-Commit Architectural Anti-Pattern Validation (The "Deep Audit" Protocol)
Before finalizing any code or creating a commit, you MUST perform a generic self-audit against core architectural boundaries. You must explicitly verify in your thought process that the new code does not violate these constraints:

1. **Memory Bounds & OOM Bloat**: Are you caching or accumulating large payloads (images, files, models) in memory? 
   - *Validation*: Ensure all in-memory caches, arrays, or dictionaries have explicit and strict hardware-bound limits (count limits, cost limits, or eviction policies). Never allow unbounded memory growth.
2. **Concurrency Leaks (Zombie Tasks)**: Are you spinning up asynchronous tasks or streams that iterate over large datasets?
   - *Validation*: Ensure every background loop explicitly checks for cancellation (`Task.isCancelled` or equivalent). Background work must die instantly when the user navigates away or cancels the operation.
3. **CPU Spin Locks & Busy-Waits**: Are you monitoring system events (I/O, network) and reacting with mutating operations?
   - *Validation*: Ensure you are not creating a tight retry loop when resources are locked. Implement explicit locking checks and aggressive debounce mechanisms to prevent 100% CPU utilization.
4. **I/O & Network Bottlenecks (The N+1 Problem)**: Are you fetching data or metadata sequentially inside a loop over a large collection?
   - *Validation*: Never execute synchronous I/O, disk stats, or IPC calls inside a loop. You must extract and collapse these into a single bulk-prefetch system call before the loop begins.
5. **UI Thread Blocking (Anti-Beachball)**: Are you performing heavy data transformations, decoding, or disk writing on the main UI thread?
   - *Validation*: Ensure all heavy allocations and processing are moved to background threads, and wrap massive memory allocations in `autoreleasepool` boundaries to prevent main thread starvation and beachballing.
6. **Data Loss via Heuristic Assumptions**: Are you executing destructive actions (delete, overwrite, move) based on partial data matching or heuristics?
   - *Validation*: Never rely on partial hashes, file sizes, or name similarities for destructive operations. Always implement a full, cryptographically secure validation fallback (e.g., full byte-for-byte or SHA-256) before destroying user data.
7. **Render Loop Thrashing**: Are you updating parent state structures from high-frequency events (like scroll or mouse tracking)?
   - *Validation*: Ensure high-frequency data is isolated to leaf-node observables or bindings to prevent cascading re-renders of large parent view hierarchies.
8. **State Desynchronization (Single Source of Truth)**: Are you copying or duplicating state across multiple stores or `@State` variables?
   - *Validation*: Never mirror state. Always derive dependent data dynamically via computed properties or pass it via bindings to guarantee a single source of truth.
9. **Retain Cycles (Memory Leaks)**: Are you using escaping closures, timers, or event monitors that reference class instances?
   - *Validation*: Always explicitly capture `[weak self]` in long-lived closures or AppKit monitors to prevent permanent memory leaks.
10. **Concurrency Race Conditions**: Are you mutating a shared dictionary, array, or cache from multiple concurrent background tasks?
    - *Validation*: Ensure all mutable shared state is strictly protected by an `actor`, a `@MainActor` wrapper, or a serial queue to prevent fatal `EXC_BAD_ACCESS` memory corruption crashes.
11. **Security & Shell Injection**: Are you passing user input, file names, or paths directly into shell commands (`Process`)?
    - *Validation*: Never use string interpolation to build shell commands. Always strictly pass user data into the `arguments` array of `Process`, bypassing shell evaluation entirely, to prevent command injection.
12. **UI/UX Silent Failures**: Are you catching errors in a user-initiated action without updating the UI?
    - *Validation*: Never swallow errors silently (e.g. `try?`) unless it's an expected background debounce. All user-initiated failures MUST bubble up to a visible UI alert or status indicator so the user knows what went wrong.
13. **Unbounded IPC & Stream Buffering (OOM Prevention)**: Are you buffering inter-process communication (IPC) or subprocess output streams directly into application memory?
    - *Validation*: Never accumulate unbounded stream data (e.g., subprocess stdout, network responses, bulk file decoding) into RAM buffers. You must always pipe massive data streams directly to disk descriptors or consume them via strict bounded chunking to prevent macOS Jetsam (OOM) termination.
14. **Main Thread Resource Decoding (Anti-Beachball)**: Are you triggering the decompression, decoding, or parsing of heavy binary assets (images, videos, archives) synchronously on the UI thread?
    - *Validation*: Never decode or load binary assets during view lifecycle events (e.g., layout passes, appearance modifiers). Asset decompression is highly CPU-bound and must strictly occur in detached background thread pools, passing only the final lightweight representation back to the main actor.
15. **Synchronous Subprocess Execution (Anti-Beachball)**: Are you launching a system `Process` and calling `waitUntilExit()` synchronously on the UI thread?
    - *Validation*: Never execute a blocking subprocess (like `zip`, `tar`, `ditto`) synchronously on the `@MainActor` (e.g., inside a Button closure). System binaries can take seconds or minutes to complete depending on the payload size. Always execute `Process` lifecycles inside a background `Task.detached` to prevent the application from beachballing.
16. **Sequential Bulk Disk I/O on the Main Actor (Anti-Beachball)**: Are you executing a loop of individual disk operations (move, delete, copy, stat) sequentially on the main actor over a collection that could be large?
    - *Validation*: Never run a `for` loop of blocking filesystem calls directly on `@MainActor`. Each iteration adds cumulative latency — 500 `moveToTrash` calls in sequence on the main thread will freeze the UI for seconds. All bulk destructive operations must be dispatched to a background task, aggregating individual errors, and only reporting the final outcome back to the main actor.
17. **N+1 Attribute Fetching in Directory Enumeration**: Are you enumerating directory contents with an empty or nil property key set, then reading file attributes (size, type, dates) inside the loop?
    - *Validation*: Never pass `nil` or an empty array to `includingPropertiesForKeys` when enumerating a directory if you intend to read any resource attributes inside the loop. The OS returns cached values for free when keys are declared upfront, but triggers a separate `stat()` syscall per file for each attribute read cold. Always declare every resource key you need at the enumeration call site so the OS bulk-prefetches them in a single round trip.
18. **Full Payload Buffering Before Network Send (OOM)**: Are you loading an entire file or data blob into memory before transmitting it over a network connection?
    - *Validation*: Never read an entire file into a single `Data` object before sending it. A single 4GB file request would allocate 4GB+ in RAM, triggering OOM termination. Always stream data in bounded fixed-size chunks — read a chunk, send it, read the next — so peak memory usage is bounded by chunk size, not file size.
19. **Synchronous I/O Inside SwiftUI `body` or Computed Properties**: Are you performing file reads, network calls, or any blocking I/O inside a SwiftUI `body`, `@ViewBuilder`, or computed property?
    - *Validation*: SwiftUI `body` executes on the main thread and may be called many times per second during layout. Any I/O inside it blocks the render thread directly. All data loading must happen inside `.task`, `.onAppear`, or equivalent async lifecycle modifiers, storing results in `@State` that the body reads passively.
20. **`NSPredicate` Format String Injection (ObjC Crash)**: Are you building an `NSPredicate` format string by interpolating user input, search queries, or any runtime string directly into the format argument?
    - *Validation*: Never interpolate variables into `NSPredicate(format:)` or `NSPredicate(format:arguments:)`. Any character with predicate syntax meaning (`%`, `\`, `(`, `)`, `'`) in the interpolated value corrupts the predicate parser and raises an `NSInvalidArgumentException` — an Objective-C exception that **cannot be caught by Swift's `try/catch`** and crashes the entire application. Always use `%@` argument substitution: `NSPredicate(format: "kMDItemFSName ==[cd] %@", value)`. The value is then treated as a data argument, never as format syntax.
21. **Block-Based `NotificationCenter` Observer Token Leak**: Are you using `NotificationCenter.default.addObserver(forName:object:queue:using:)` — the closure-based form that returns an `NSObjectProtocol` token?
    - *Validation*: The block-based observer form always returns an opaque token that **must be stored and explicitly removed** via `NotificationCenter.default.removeObserver(_:)`. Discarding the return value registers a persistent, anonymous observer that can never be removed. Every subsequent call to the same registration site stacks a new ghost observer. After N registrations, every matching notification fires all N closures simultaneously, causing duplicated work, corrupted results, and a permanent memory leak for the session. Always store the token in a property (`private var observer: NSObjectProtocol?`), remove the previous one before re-registering, and remove it again inside the handler immediately after it fires once.
22. **Missing Cancellation Check in Long-Running Async Loops**: Are you iterating over a large collection inside an `async` function or `Task.detached` without checking for task cancellation?
    - *Validation*: An `async` function that loops over a large dataset (files, URLs, chunks) continues running even after its parent `Task` is cancelled — it becomes a zombie consuming CPU, disk I/O, or battery with no way to abort. Always call `try Task.checkCancellation()` (or check `Task.isCancelled`) at the top of each loop iteration. This guarantees the operation exits the moment the user cancels or navigates away, without requiring any external coordination.

## 30. Standard Modal/Sheet Screen Pattern (MANDATORY for every new sheet/modal)
Every modal in this app (`AutoOrganizationSheet`, `HelpSheet`, `AboutSheet`, `SettingsView`,
`FilePropertiesSheet`, `SymlinkSheetView`, `DiskSpaceVisualizerSheetView`, `FolderPickerSheet`,
`BatchRenameSheetView`, `ImageConverterSheetView`, `ArchiveInspectionSheetView`,
`DuplicateCleanerSheetView`, `HttpShareSheet`, etc.) already follows the exact same skeleton. When
adding or editing a modal, do not improvise a new layout, a new close mechanism, or new spacing
convention — copy this pattern:

- **Structure**: `VStack { headerView; Divider(); contentArea; Divider(); footerView }`. Content
  between the two `Divider()`s is the only part that scrolls or grows; header and footer stay fixed.
- **Always present as a real `.sheet(isPresented:)`, never as its own `Scene`** (e.g. `Settings { }`,
  a second `WindowGroup`). A `Scene` always comes with its own native title bar and traffic-light
  window chrome that visually fights this header/footer pattern — and that chrome cannot be reliably
  stripped: `.windowStyle(.hiddenTitleBar)` silently has no effect on a `Settings` scene, and
  reaching into the real `NSWindow` via `NSViewRepresentable` to hide the buttons/title bar directly
  still leaves rendering glitches (blank strips, clipped content) that aren't worth chasing. A sheet
  has no window chrome to begin with, so the standard pattern applies with zero extra work — see
  `SettingsView.swift`, wired through `windowUIState.showSettingsSheet` like every other sheet flag.
- **Multi-tab screens**: put the tab switcher *inside* `headerView`, below the icon/title/subtitle
  row. Don't reach for `Picker(selection:).pickerStyle(.segmented)` if the tabs need icons — macOS
  silently drops the icon from a `Label` there, even with `.labelStyle(.titleAndIcon)` applied
  (text-only in practice). Hand-roll the tab row instead (icon above title, centered, selected-state
  tint) — see `SettingsView.swift`'s `tabSwitcher`.
- **Header**: a leading icon + a `VStack(alignment: .leading, spacing: 2)` holding a bold title and,
  directly beneath it, a one-line secondary subtitle (`.font(.system(size: 11))`,
  `.foregroundColor(.secondary)`) describing what the screen is for — never ship a header with just a
  bare title and no subtitle. Give the header its own subtle background tint,
  `.background(Color(NSColor.controlBackgroundColor).opacity(0.5))`, when the sheet has enough visual
  weight to need one (skip it only for the simplest single-field dialogs). **Never put a close/X
  button in the header** — every existing sheet in this app closes exclusively through the footer,
  never through a header button. Adding one is an inconsistency bug, not a feature.
- **Footer**: `HStack { Spacer(); primaryButton }` — right-aligned, never centered, never left-aligned.
  The primary action (`Done`/`Close`/`Create`/etc.) carries `.keyboardShortcut(.defaultAction)`. For a
  two-button Cancel/Confirm flow, place `Cancel` immediately before the primary button inside the same
  right-aligned `HStack` (still after `Spacer()`), and give `Cancel` `.keyboardShortcut(.escape,
  modifiers: [])` explicitly.
- **Closing on Escape**: real `.sheet(...)`-presented views get Escape-to-close for free from
  AppKit/SwiftUI — do not add anything for those. The one exception is a view NOT presented via
  `.sheet(...)` (e.g. `ShortcutsHUDOverlay`, a manual full-window `ZStack` overlay) — those get no
  native Escape handling and must wire it explicitly. **Do not use `.onExitCommand` for this** — it
  only fires when something inside that view subtree actually holds keyboard focus, which a manual
  overlay with no focusable field never establishes, so it silently never fires. Instead add an
  invisible `Button("") { ... }.keyboardShortcut(.escape, modifiers: []).hidden()` inside the overlay,
  the same technique `MainContentView`'s own hidden shortcut buttons use — and make sure no other
  view in the hierarchy (e.g. `MainContentView`'s global hidden `.keyboardShortcut(.escape)` deselect
  button) is still capturing Escape first; `.disabled(...)` it while the overlay is showing if so.
- **Container chrome**: fixed `.frame(width:, height:)` (or width-only when height should hug
  content) declared once on the outermost `VStack`, plus `.background(Color(NSColor
  .windowBackgroundColor))`. Never leave a modal without this background — it's what makes the sheet
  look like every other sheet in the app instead of a visually distinct one-off.
- **Padding**: apply padding per-section (header, footer, and the content area's own inner
  container), not as one blanket `.padding(20)` around the whole `VStack`. A scrollable content area
  should extend its `ScrollView` close to the container's true edges (so the scrollbar sits near the
  edge, not inset by the header's padding) while its own inner content still carries the same
  horizontal padding as the header/footer for visual alignment.

## 31. Apple HIG Alignment & Control Conventions (MANDATORY — check against the real macOS equivalent)
Before shipping any new control cluster, compare it directly to the closest native macOS System
Settings / Safari Preferences / Finder equivalent and match *its* alignment and control choice —
don't improvise a layout that merely "looks plausible." General rules:

- **A mutually-exclusive mode/view switcher (tabs, segmented control) is horizontally centered in
  its row**, never left- or right-aligned — this is how System Settings tab bars and Safari
  Preferences' segmented groups are laid out.
- **A settings/data row (label ... value) is the opposite**: leading-aligned label, trailing-aligned
  value/control, connected by a `Spacer()` in between. This is the correct pattern for rows *inside*
  a list or form, not for a standalone control cluster that isn't part of a list.
- **Prefer a native control over a hand-rolled one** when the requirement fits: e.g.
  `Picker(selection:).pickerStyle(.segmented)` over custom `Button` rows for simple mutually-exclusive
  selection. Only hand-roll a custom control when the native one genuinely can't express a
  requirement — and even then, the hand-rolled version must still follow the alignment convention the
  native control would have used.
- **Footer action buttons are right-aligned** (see rule 30) — never centered, never left-aligned,
  regardless of how few buttons there are; a single lonely action button is still right-aligned, not
  centered.
- When genuinely unsure which alignment applies, open the closest matching native macOS panel
  (System Settings, Safari Preferences, Finder Get Info) and copy what it does, rather than guessing.
- **Trailing accessories (a value, a keycap badge, a status label, a chevron) sit close to the row's
  true trailing edge**, not symmetrically inset to match the leading padding. Native macOS list/table
  rows (Finder list view, System Settings rows) give trailing content a small, tight margin — if the
  row container needs asymmetric padding (smaller trailing than leading) to achieve that, use it;
  don't default to a single uniform `.padding(.horizontal:)` value out of habit.
- **Don't stack two horizontal dividers back-to-back**, or draw a divider immediately before another
  structural divider already provides the same separation (e.g. rule 30's header/content/footer
  dividers). A `Divider()` should mark one genuine structural boundary; separate items or sub-groups
  *within* a content region using `VStack`/`HStack` `spacing` instead of literal drawn lines, and only
  reach for an extra divider when spacing alone doesn't communicate the grouping.

## 32. Window-Scoped UI State Must Never Live on the Shared `AppState`
- **`AppState` is a single instance shared by every open Wiles window.** Any sheet, alert, HUD, or
  "currently editing/inspecting this item" flag stored directly on `AppState` (or on a store
  hanging off it, like `ModalStore`) fires in **every** open window simultaneously the moment one
  window sets it — e.g. opening "Properties" in window A pops the Properties sheet in window B too,
  toggling the shortcuts cheatsheet in one window shows it in all of them. This is a real,
  previously-shipped bug class, not a hypothetical.
- **Any state that represents "what this specific window is currently showing/presenting" belongs on
  a dedicated per-window `@Observable` state object** (see `WindowUIState`), instantiated as `@State`
  inside the window's root content view (`MainContentView`) so SwiftUI gives each window its own
  instance automatically.
- **Wiring pattern**: inject the per-window object into that window's view hierarchy with
  `.environment(_:)` at the root, and read it in any descendant view with
  `@Environment(WindowUIState.self)` — this requires no constructor/parameter changes down the view
  tree, since `.sheet`/`.popover`/`.contextMenu` content all inherit the presenter's environment.
  For code that lives *outside* any single window's view hierarchy (menu `Commands` in the `App`
  struct), publish the object from the root view via `.focusedSceneValue(\.someKey, windowUIState)`
  and read it there with `@FocusedValue(\.someKey)` — never `.focusedValue`/`@FocusedValue` paired
  with `.focusedValue(_:)`, which requires an actual native SwiftUI-focused control; this app runs
  its own `NSEvent` monitors instead of native focus, so `.focusedValue` silently never fires.
  AppKit-level code reached through an `NSViewRepresentable` (custom key-event monitors, etc.) gets
  the per-window object threaded through as an explicit parameter, same as `AppState` already is.
- **Exception**: state with no natural "owning window" — e.g. an error alert triggered by a
  background service (a stalled auto-organization scan, a network op with no UI in front of it) —
  legitimately stays on the shared `AppState`/`ModalStore`, since the user needs to see it regardless
  of which window (if any) currently has focus. Only move state that is set as the direct result of
  an explicit action taken *in* one specific window.

## 33. Custom Button/Tappable Content MUST Have an Explicit `.contentShape` (repeat offender — check every time)
- **A `Button` (or `.onTapGesture`) whose label is composite content** — an `Image` + `Text` in a
  `VStack`/`HStack`, an icon with surrounding padding, anything that isn't a single opaque `Text` —
  is **only tappable on its actual rendered, non-transparent pixels** by default. Clicking the visible
  padding around an icon, or the gap between an icon and its label, silently does nothing — this
  reads to the user as "the button doesn't work," not as a hit-testing subtlety, and it has shipped
  more than once in this app.
- **On macOS, a real `Button` does not reliably honor `.contentShape` at all for this** — not just
  when the shape is oversized, but even when it's set to `Rectangle()` matched *exactly* to the
  label's own frame. `Button`'s AppKit-backed click routing keeps tracking only the rendered
  content's actual bounds regardless of what `.contentShape` you attach. **Never use `Button` for a
  composite-content control where the padding around the content needs to be tappable** — use a plain
  view with `.contentShape(Rectangle())` + `.onTapGesture { }` instead (add
  `.accessibilityAddTraits(.isButton)` + `.accessibilityLabel(...)` since it's no longer a real
  control). This combination is what actually respects `.contentShape`, matched or oversized alike —
  see `SettingsView.swift`'s `tabButton`. This is the default, non-negotiable way to write any custom
  tappable view with non-trivial label content — not something swapped in reactively after a bug
  report.
- **Keep `.contentShape(Rectangle())` matched exactly to the visible frame — do not outset it past
  that frame unless there is real, uninterrupted empty space on every side you're growing into.** A
  row of adjacent tappable controls (a tab switcher, a segmented row, icon buttons a few points apart)
  almost never has that space: outsetting each one's hit region past its own bounds makes neighboring
  regions overlap, so a click near the boundary — or even solidly inside one control — can register on
  the *wrong* sibling. This has actually shipped in `SettingsView.swift`'s tab row (clicking "General"
  selected a different tab). If a bigger tap target is genuinely needed for controls packed this
  tightly, increase the real `HStack`/`VStack` `spacing` between them first so there's slack to grow
  into, rather than letting hit regions silently overlap.

## 34. Script Any Manual Command Sequence You Run More Than Once
- Second time you chain the same multi-step shell sequence, make it a `scripts/*.sh` file and call
  it by name instead of re-typing. Full description lives in each script's own header comment.
- `scripts/push_and_relaunch.sh "<msg>" [--skip-commit]` — build+sign+relaunch, then commit+push.
  Default to `--skip-commit` until told to commit (rule 10).
- `scripts/validate.sh` — build+test+lint+format, exit 0 = clean.
- `scripts/build_release.sh` — packages release `.zip`/`.dmg`/`.sha256`.
- `scripts/release.sh` — validate → build_release → update Homebrew Cask → push.
- `scripts/test_timing.sh` — slowest 10 tests.
- `scripts/setup_test_ramdisk.sh` — mounts RAM disk for tests.

## 35. Never Destroy User Data — Fail Loud and Untouched, Never Fail Silently Mid-Operation
- **A destructive filesystem operation (move, delete, overwrite) must never leave the user with
  less than they started with.** If any precondition isn't clearly safe, abort before touching
  anything — do not "clean up" the destination, delete-then-recreate, or otherwise perform a
  partial/irreversible step before the operation is confirmed possible.
- **Real incident this rule is written from**: `FileSystemService.moveItem(at:toFolder:)` used to
  unconditionally `removeItem(at: destURL)` "to clear the way" before calling `moveItem`. When the
  destination happened to be the exact same path as the source (dragging a folder onto the folder
  it's already in), this deleted the user's folder outright, then failed to move it (source no
  longer existed) — permanent data loss, not even recoverable from Trash, surfaced only as a
  confusing untranslated system error. See the regression test in
  `Tests/WilesTests/FileSystem/FileSystemMoveRegressionTests.swift`.
- **Concretely**: any function that removes/overwrites a destination "to make room" for a move or
  write MUST first verify the destination isn't the source itself (compare `.standardizedFileURL`,
  per rule 20) and MUST NOT proceed with the destructive half of the operation unless the
  constructive half is actually going to happen. Prefer erroring out over guessing.
- **Every fix for a data-loss bug must ship with a red→green regression test** (rule 28) that
  proves the old code actually destroyed data and the new code doesn't — not just "doesn't throw."

## 36. No Embedded Text/Templates/HTML/Markup in Swift Source
- **Never build multi-line text blobs — HTML, XML, Markdown, templated document formats — via
  string concatenation or interpolation inside a `.swift` file.** Any real content document longer
  than a one-line string belongs in its own resource file under `Resources/` (e.g. an `.html`
  template), loaded at runtime and populated via placeholder substitution — never assembled
  line-by-line in Swift.
- **Real example this rule is written from**: `LocalHttpServerService.serveDirectoryListing`
  hand-built an entire HTML page via `var html = "..."; html += "..."` chains directly in Swift.
  This mixes markup-authoring concerns into application logic, makes the markup impossible to
  preview/edit as HTML, and doesn't scale past one hardcoded page.
- **Concretely**: static markup/structure (page chrome, styles, wrapper tags) lives in a template
  resource file; only genuinely dynamic fragments (e.g. a generated list of `<li>` rows) get
  assembled in Swift, then substituted into a single placeholder in the loaded template — never the
  whole document.

## 37. Public `RELEASE_NOTES.md` — Keep Only the Last 5 Versions in Full, Then Consolidate
- **Applies to `marcops/wiles` (public repo) `RELEASE_NOTES.md`.** Keep the 5 most recent version
  entries in full detail (New Features, Bug Fixes, Security Fixes, Performance, Refinements — same
  as today).
- **On adding a 6th entry**: before adding the new version at the top, collapse everything older
  than the (now) most recent 5 into a single trailing `## Earlier Versions` (or similarly named)
  consolidated section. That consolidation lists **major features only** — one line per shipped
  feature, no bug fixes, no perf notes, no minor refinements — across all the versions being
  folded in. If a consolidated section already exists from a previous rotation, merge the newly
  -demoted version's major features into it rather than creating a second one.
- **Why**: the file is public-facing marketing history, not a changelog archive — recent detail is
  useful to evaluate what just shipped, but a growing wall of old bug-fix bullets buries it. A short
  "what Wiles has grown into" summary at the bottom stays useful indefinitely.
