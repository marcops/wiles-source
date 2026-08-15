# UI Test Backlog

Manual-review items that can't be covered by the current test harness (state-only, no
snapshot/screenshot testing) and are pending eventual coverage.

- Search field layout: "Whole Mac" toggle and filter icon must stay right-aligned inside the
  search bar (`HeaderBarView.searchField`), not centered. Fixed by making `searchTextField`
  expand (`maxWidth: .infinity, alignment: .leading`) so it absorbs the extra space instead of
  the whole HStack being centered.
