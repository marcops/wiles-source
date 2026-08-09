import Foundation
import Network

@Observable
@MainActor
public final class NetworkDiscoveryService {
    public static let shared = NetworkDiscoveryService()

    public var discoveredShares: [NetworkShare] = []

    private var browser: NWBrowser?
    private let queue = DispatchQueue(label: "com.wiles.NetworkDiscovery")

    private init() {
        startBrowsing()
    }

    public func startBrowsing() {
        if browser != nil { return }

        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        let browser = NWBrowser(for: .bonjour(type: "_smb._tcp", domain: "local."), using: parameters)

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                self?.updateDiscoveredShares(from: results)
            }
        }

        browser.start(queue: queue)
        self.browser = browser
    }

    public func stopBrowsing() {
        browser?.cancel()
        browser = nil
        discoveredShares = []
    }

    private func updateDiscoveredShares(from results: Set<NWBrowser.Result>) {
        var newShares: [NetworkShare] = []
        for result in results {
            if case let .service(name, _, _, _) = result.endpoint {
                // Encode the name to form a valid URL
                if let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed),
                   let url = URL(string: "smb://\(encodedName).local") {
                    newShares.append(NetworkShare(name: name, url: url))
                }
            }
        }
        self.discoveredShares = newShares.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
