import AppKit
import Foundation

@MainActor
public final class SpotlightSearchService {
    public static let shared = SpotlightSearchService()

    private var metadataQuery: NSMetadataQuery?
    private var completionHandler: (([URL]) -> Void)?

    private init() { }

    public func searchFiles(
        matching queryText: String,
        scopeURL: URL,
        completion: @escaping ([URL]) -> Void) {
        stopSearch()
        guard !queryText.trimmingCharacters(in: .whitespaces).isEmpty else {
            completion([])
            return
        }

        let query = NSMetadataQuery()
        completionHandler = completion
        metadataQuery = query

        // Splicing user input directly into the predicate *format string* (the old `'*\(query)*'`
        // approach) means any apostrophe in the search text breaks out of the quoted literal and
        // corrupts the predicate syntax — NSPredicate(format:) then raises an NSInvalidArgumentException,
        // which is an Objective-C exception, not a Swift Error, so it cannot be caught and crashes the
        // whole app. %@ substitution passes the value as a genuine argument instead of format syntax,
        // so it's never parsed and can't break out no matter what characters it contains.
        let trimmedQuery = queryText.trimmingCharacters(in: .whitespaces)
        let wildcardQuery = "*\(trimmedQuery)*"
        query.predicate = NSPredicate(format: "(kMDItemFSName ==[cd] %@) || (kMDItemDisplayName ==[cd] %@)", wildcardQuery, wildcardQuery)

        query.searchScopes = [scopeURL.path]

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(queryDidFinishGathering(_:)),
            name: .NSMetadataQueryDidFinishGathering,
            object: query)

        query.start()
    }

    public func stopSearch() {
        if let query = metadataQuery {
            query.stop()
            NotificationCenter.default.removeObserver(
                self,
                name: .NSMetadataQueryDidFinishGathering,
                object: query)
        }
        metadataQuery = nil
        completionHandler = nil
    }

    @objc
    private func queryDidFinishGathering(_: Notification) {
        guard let query = metadataQuery else { return }
        query.stop()

        var results: [URL] = []
        let count = query.resultCount
        for i in 0 ..< count {
            if let item = query.result(at: i) as? NSMetadataItem,
               let path = item.value(forAttribute: kMDItemPath as String) as? String {
                results.append(URL(fileURLWithPath: path))
            }
        }

        let handler = completionHandler
        stopSearch()
        handler?(results)
    }
}
