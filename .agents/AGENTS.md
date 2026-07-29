# AGENTS.md - Senior Apple Swift Architect Rules & Guidelines for Wiles

## 1. Core Architectural Principles (KISS, YAGNI, DRY, SOLID)
- **KISS (Keep It Simple, Stupid)**: Prefer straightforward, clean SwiftUI state management over over-engineered abstractions or unnecessary layers. Write clear, maintainable Swift code.
- **YAGNI (You Aren't Gonna Need It)**: Build features strictly for concrete requirements. Avoid speculative code or unused generic wrappers.
- **DRY (Don't Repeat Yourself)**: Never duplicate context menus, selection handlers, drag & drop handlers, or item rendering logic across `FileGridView` and `FileListView`.
- **Single Responsibility Principle (SRP)**: Keep Views focused on layout declaration, Services (`FileSystemService`, `LocalizationService`, `ZipArchiveService`) focused on system logic, and `AppState` focused on application state.
- **Dedicated Feature Service Classes**: Each domain feature or system subsystem MUST reside in its own dedicated, isolated Swift service class file (e.g. `Sources/Wiles/Services/ZipArchiveService.swift`). Never bloat existing service files with unrelated feature logic.
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
- **Agent Responses in English**: All agent responses to the user MUST be written in English.
- **Strict Command Discipline**: DO NOT run `git commit` or `git push` or publish release binaries/archives unless the user explicitly requests it.

## 11. Repository Architecture & Public/Private Separation
- **`marcops/wiles` (PUBLIC REPOSITORY)**: Contains public Homebrew cask formulas (`Casks/wiles.rb`), public release assets (`releases/wiles-vX.Y.Z.dmg`, `releases/wiles-vX.Y.Z.zip`), documentation, and public issue tracking. All Homebrew cask URLs MUST point exclusively to this public repository (`https://raw.githubusercontent.com/marcops/wiles/main/...`).
- **`marcops/wiles-source` (PRIVATE REPOSITORY)**: Contains internal Swift source code. NEVER reference private URLs (`wiles-source`) in public Homebrew formulas or public documentation.

## 12. Automated Homebrew & Release Packaging Protocol
- **Zip Packaging Requirement**: ALWAYS use `/usr/bin/zip -r -y dist/wiles-vX.Y.Z.zip Wiles.app` to ensure the root `Wiles.app/` folder is preserved inside the archive. Never use `ditto` directly on `Wiles.app` for Homebrew releases as it strips the root folder.
- **CDN Cache Busting (CRITICAL)**: When updating `Casks/wiles.rb`, the `url` MUST use the **exact git commit SHA** where the `.zip` was pushed (e.g., `url "https://raw.githubusercontent.com/marcops/wiles/<COMMIT_SHA>/releases/wiles-v#{version}.zip"`). Never use `main` in the URL, as GitHub's Fastly CDN will cache the old binary and cause a Homebrew SHA256 mismatch error.
- **SHA256 Verification Checklist**:
  1. Build release binary `swift build -c release` and sign `Wiles.app`.
  2. Package DMG `hdiutil create -volname "Wiles" -srcfolder Wiles.app -ov -format UDZO releases/wiles-vX.Y.Z.dmg`. (DMG is correct)
  3. Package ZIP `/usr/bin/zip -r -y dist/wiles-vX.Y.Z.zip Wiles.app`.
  4. Compute `shasum -a 256 dist/wiles-vX.Y.Z.zip`.
  5. Copy ZIP & DMG to public tap repo `marcops/wiles/releases/`.
  6. Push binaries to public repo first and get the exact commit SHA.
  7. Update `Casks/wiles.rb` version, SHA256, and URL with the exact commit SHA.
  8. Push the Cask update to public repo and verify live with `curl` before declaring completion.


