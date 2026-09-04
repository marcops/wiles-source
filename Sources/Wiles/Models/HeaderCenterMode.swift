import Foundation

/// What the header's center region shows: the breadcrumb path bar, the editable search field, or a
/// non-editable name pill for a nameable search context (a saved smart folder, or a lone `tag:`
/// token). Pure function of the current search/window state so it can be unit-tested without a View.
public enum HeaderCenterMode: Equatable {
    case breadcrumb
    case editableSearch
    case tagPill(tag: String)
    case smartFolderPill(name: String)

    public static func resolve(
        isSearching: Bool,
        isEditingSearch: Bool,
        activeSmartFolderName: String?,
        searchQuery: String) -> Self {
        guard isSearching else { return .breadcrumb }
        if isEditingSearch {
            return .editableSearch
        }
        if let name = activeSmartFolderName {
            return .smartFolderPill(name: name)
        }
        if let tag = SearchFilterService.soleTagValue(in: searchQuery) {
            return .tagPill(tag: tag)
        }
        return .editableSearch
    }
}
