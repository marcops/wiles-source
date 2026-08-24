import SwiftUI

/// Shared "run an async operation, then show loading vs. empty-state vs. results" orchestration.
///
/// Several features (`ArchiveInspectionSheetView`, `DuplicateCleanerSheetView`,
/// `DiskUsageSidebarView`) each hand-rolled the identical state machine: an `isLoading`/`isScanning`
/// flag, an optional result, a `.task` that awaits a service call, and an `if/else if` chain over
/// loading/empty/results. This factors that into one reusable implementation that stays
/// cancellation-safe by construction — the awaited value is only written back if the driving
/// `.task(id:)` hasn't been superseded/cancelled in the meantime, so a stale run can never clobber
/// a newer one's state.
///
/// `id` drives re-runs exactly like `.task(id:)` does: pass something that changes whenever the
/// operation should run again (e.g. the current directory URL for a sidebar that tracks
/// navigation). Callers that only ever run the operation once per appearance (a modal sheet whose
/// backing data never changes for the sheet's lifetime) can omit `id` via the `ID == Int`
/// convenience initializer below, which behaves like the bare `.task { ... }` (no `id:`) each of
/// those call sites used before.
struct AsyncResultView<Result: Sendable, ID: Equatable, Loading: View, Empty: View, Content: View>: View {
    let id: ID
    let operation: () async -> Result
    let isEmpty: (Result) -> Bool
    @ViewBuilder let loading: () -> Loading
    @ViewBuilder let empty: () -> Empty
    @ViewBuilder let content: (Result) -> Content

    @State private var result: Result?

    var body: some View {
        Group {
            if let result {
                if isEmpty(result) {
                    empty()
                } else {
                    content(result)
                }
            } else {
                loading()
            }
        }
        .task(id: id) {
            // Reset to the loading state on every re-run (not just the first), so an `id` change
            // that re-triggers the operation (e.g. navigating to a new directory) shows loading
            // again instead of leaving the previous directory's stale results on screen.
            result = nil
            let value = await operation()
            // Guards against a superseded run: if `id` changed again (or the view disappeared)
            // while `operation` was in flight, this task was cancelled and must not overwrite
            // whatever the newer run already produced.
            if !Task.isCancelled {
                result = value
            }
        }
    }
}

extension AsyncResultView where ID == Int {
    /// Convenience for a one-shot operation with no re-run key.
    init(
        operation: @escaping () async -> Result,
        isEmpty: @escaping (Result) -> Bool,
        @ViewBuilder loading: @escaping () -> Loading,
        @ViewBuilder empty: @escaping () -> Empty,
        @ViewBuilder content: @escaping (Result) -> Content) {
        self.init(id: 0, operation: operation, isEmpty: isEmpty, loading: loading, empty: empty, content: content)
    }
}
