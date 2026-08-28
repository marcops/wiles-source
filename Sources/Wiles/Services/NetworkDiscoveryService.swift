import Foundation
import Network

@Observable
@MainActor
public final class NetworkDiscoveryService {
    public static let shared = NetworkDiscoveryService()

    public var discoveredShares: [NetworkShare] = []

    private var browser: NWBrowser?
    private let queue = DispatchQueue(label: "com.wiles.NetworkDiscovery")

    /// No discovery on construction — `SidebarView` calls `start()`/`stop()` tied to the
    /// "Network & Cloud" section's visibility so the SMB browser isn't live for the whole app run.
    private init() { }

    public func start() {
        if browser != nil {
            return
        }

        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        let browser = NWBrowser(for: .bonjour(type: "_smb._tcp", domain: "local."), using: parameters)

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                guard let self else { return }
                self.updateDiscoveredShares(from: results)
            }
        }

        browser.start(queue: queue)
        self.browser = browser
    }

    public func stop() {
        browser?.cancel()
        browser = nil
        discoveredShares = []
    }

    private func updateDiscoveredShares(from results: Set<NWBrowser.Result>) {
        // Encode the name to form a valid URL
        let newShares = results.compactMap { result -> NetworkShare? in
            guard case let .service(name, _, _, _) = result.endpoint,
                  let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed),
                  let url = URL(string: "smb://\(encodedName).local") else { return nil }
            return NetworkShare(name: name, url: url)
        }
        discoveredShares = newShares.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
