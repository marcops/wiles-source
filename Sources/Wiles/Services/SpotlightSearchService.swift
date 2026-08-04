import Foundation
import AppKit

@MainActor
public final class SpotlightSearchService {
    public static let shared = SpotlightSearchService()

    private var metadataQuery: NSMetadataQuery?
    private var completionHandler: (([URL]) -> Void)?

    private init() {}

    public func searchFiles(
        matching queryText: String,
        scopeURL: URL,
        completion: @escaping ([URL]) -> Void
    ) {
        stopSearch()
        guard !queryText.trimmingCharacters(in: .whitespaces).isEmpty else {
            completion([])
            return
        }

        let query = NSMetadataQuery()
        self.completionHandler = completion
        self.metadataQuery = query

        let trimmedQuery = queryText.replacingOccurrences(of: "\"", with: "\\\"")
        let predicateString = "(kMDItemFSName ==[cd] '*\(trimmedQuery)*') || (kMDItemDisplayName ==[cd] '*\(trimmedQuery)*')"
        query.predicate = NSPredicate(format: predicateString)

        query.searchScopes = [scopeURL.path]

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(queryDidFinishGathering(_:)),
            name: .NSMetadataQueryDidFinishGathering,
            object: query
        )

        query.start()
    }

    public func stopSearch() {
        if let query = metadataQuery {
            query.stop()
            NotificationCenter.default.removeObserver(
                self,
                name: .NSMetadataQueryDidFinishGathering,
                object: query
            )
        }
        metadataQuery = nil
        completionHandler = nil
    }

    @objc private func queryDidFinishGathering(_ notification: Notification) {
        guard let query = metadataQuery else { return }
        query.stop()

        var results: [URL] = []
        let count = query.resultCount
        for i in 0..<count {
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
