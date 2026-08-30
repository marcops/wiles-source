import SwiftUI

/// Shared "slice the dataset + grow-on-scroll" pagination logic used inside both the grid's
/// `LazyVGrid` and the list's `LazyVStack` — the two leaf renderers differ only in the per-item
/// view they render (`itemContent`) and the height reserved for the trailing loading spinner.
///
/// Above `LayoutTokens.paginationThreshold` items, only `visibleLimit` items are actually rendered;
/// scrolling the trailing `ProgressView` into view grows the limit by `lazyLoadingBatchSize` until
/// the full dataset is visible. Below the threshold, the whole dataset renders at once with the
/// entrance animation `FileGridView`/`FileListView` already relied on.
struct PaginatedItemsSection<ItemContent: View>: View {
    /// `static let` stored properties aren't allowed on a generic type, so this is computed.
    private static var lazyLoadingBatchSize: Int {
        100
    }

    let items: [FileItem]
    @Binding var visibleLimit: Int
    let progressViewHeight: CGFloat
    @ViewBuilder let itemContent: (FileItem) -> ItemContent

    private var paginate: Bool {
        items.count > LayoutTokens.paginationThreshold
    }

    /// Slice, not a fresh Array: `prefix`/`[...]` share the backing store, so `body` allocates nothing.
    private var visibleItems: ArraySlice<FileItem> {
        paginate ? items.prefix(visibleLimit) : items[...]
    }

    var body: some View {
        // No collection-level `.animation` here: it animated a full grid/list reflow on any change
        // to the item set and re-allocated a `[URL]` every `body`. Entrance animation is now the
        // per-row `.transition`, played when the caller wraps the dataset swap in `withAnimation`.
        ForEach(visibleItems) { item in
            itemContent(item)
                .transition(.opacity)
        }
        if paginate, visibleLimit < items.count {
            ProgressView()
                .frame(height: progressViewHeight)
                .onAppear {
                    visibleLimit = min(items.count, visibleLimit + Self.lazyLoadingBatchSize)
                }
        }
    }
}
