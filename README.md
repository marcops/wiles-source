# Wiles

Native macOS file manager, built with SwiftUI/AppKit and distributed as a Swift Package executable.

This is the source repo: app code, tests, and the release pipeline. The user-facing repo — README, feature tour, and the Homebrew cask — lives at [marcops/wiles](https://github.com/marcops/wiles).

## Requirements

- macOS 14+
- Swift 6 toolchain (Xcode 16+)

## Build & run

```bash
swift build
swift run
```

## Test

```bash
swift test
```

UI tests live under `UITestRunner/` — see `scripts/run_ui_test.sh`.

## Before committing

A pre-commit hook (`.githooks/pre-commit`) lints staged Swift files with SwiftLint/SwiftFormat. Run the full check — build, tests, lint — before pushing or cutting a release:

```bash
scripts/validate.sh
```

## Project rules

Engineering, architecture, and collaboration rules live under `.agents/` — read them before writing or reviewing code here (see [CLAUDE.md](CLAUDE.md) for the index).

## Release

CI/release automation is in `.github/workflows/release.yml`. Release notes and the feature changelog are maintained in the [public repo](https://github.com/marcops/wiles).
