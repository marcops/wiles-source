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
- **Composition over Inheritance**: Prefer SwiftUI View Composition, struct values, extensions, and protocol conformance over deep class hierarchies.

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




