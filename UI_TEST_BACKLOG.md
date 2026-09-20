# UI Test Backlog

Pending test coverage for work that's shipped but not yet locked in with tests, per
`WILES_RULES.md`'s "Testable Fixes Are Deferred, Not Skipped" — the user reviews real behavior
first, then these get written. Completed items are deleted, not checked off.

## Shortcuts Settings tab + Custom key remapping

- `ShortcutBinding`, `ShortcutLabelFormatter.label`, `ShortcutRegistry.preset(for:)`,
  `ShortcutRegistry.label(_:in:)`, `ShortcutRegistry.conflictingCommand(for:excluding:in:)` — pure,
  no `AppState` dependency, high-value `WilesTests` candidates.
- `ViewPreferences.applyPreset`/`setShortcutBinding` — persistence + live-store round-trip.
- `ShortcutsSettingsView`'s capture flow: tap a row, press a combo, confirm the row updates and the
  new combo actually fires the action; trigger a conflict deliberately and confirm both the
  Continue and Cancel paths of the confirmation dialog. `UITestRunner` walkthrough candidate (View
  layer, excluded from the 100% unit-test target).
- `ShortcutsHUDOverlay`'s single-list rendering reflecting live Windows/Mac/Custom bindings, incl.
  the two newly-added rows (`Select All`, `New File`). `UITestRunner` walkthrough candidate.
- `UITestRunner/Sources/uitestrunner/Walkthrough/Navigation.swift`'s `featNavigationModeWindows`
  step drives the Windows/Mac picker via the old location (Settings → General). That picker moved
  to a new "Shortcuts" Settings tab as part of this feature — this step needs updating to open that
  tab instead, once the new tab's layout is manually confirmed.
