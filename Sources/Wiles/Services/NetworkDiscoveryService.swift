import Foundation
import Network

@Observable
@MainActor
public final class NetworkDiscoveryService {
    public static let shared = NetworkDiscoveryService()

    public var discoveredShares: [NetworkShare] = []

    private var browser: NWBrowser?
    private let queue = DispatchQueue(label: "com.wiles.NetworkDiscovery")

    /// Service-instance names currently advertised by the browser.
    private var advertisedNames: Set<String> = []
    /// URLs built from a resolved host/port, keyed by service-instance name.
    private var resolvedURLs: [String: URL] = [:]
    /// In-flight endpoint resolvers, one per service-instance name.
    private var resolvers: [String: NWConnection] = [:]

    private static let smbScheme = "smb"
    private static let mdnsHostSuffix = ".local"
    private static let defaultSMBPort = 445
    private static let resolveTimeout: Duration = .seconds(5)

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
        for resolver in resolvers.values {
            resolver.stateUpdateHandler = nil
            resolver.cancel()
        }
        resolvers.removeAll()
        advertisedNames.removeAll()
        resolvedURLs.removeAll()
        discoveredShares = []
    }

    private func updateDiscoveredShares(from results: Set<NWBrowser.Result>) {
        var current: Set<String> = []
        for result in results {
            guard case let .service(name, _, _, _) = result.endpoint else { continue }
            current.insert(name)
            if shouldStartResolving(name) {
                beginResolving(name: name, endpoint: result.endpoint)
            }
        }

        for stale in advertisedNames.subtracting(current) {
            if let staleResolver = resolvers.removeValue(forKey: stale) {
                staleResolver.stateUpdateHandler = nil
                staleResolver.cancel()
            }
            resolvedURLs.removeValue(forKey: stale)
        }

        advertisedNames = current
        rebuildShares()
    }

    private func shouldStartResolving(_ name: String) -> Bool {
        resolvers[name] == nil && resolvedURLs[name] == nil
    }

    private func rebuildShares() {
        let shares = advertisedNames.compactMap { name -> NetworkShare? in
            guard let url = resolvedURLs[name] ?? Self.fallbackURL(forServiceName: name) else { return nil }
            return NetworkShare(name: name, url: url)
        }
        discoveredShares = shares.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    // The service-instance name can differ from the mDNS hostname, so resolve the real host/port first.
    private func beginResolving(name: String, endpoint: NWEndpoint) {
        let connection = NWConnection(to: endpoint, using: .tcp)
        resolvers[name] = connection

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                Task { @MainActor in
                    guard let self else { return }
                    self.finishResolving(name: name, resolvedEndpoint: self.resolvers[name]?.currentPath?.remoteEndpoint)
                }
            case .failed, .cancelled:
                Task { @MainActor in self?.finishResolving(name: name, resolvedEndpoint: nil) }
            default:
                break
            }
        }
        connection.start(queue: queue)

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.resolveTimeout)
            self?.finishResolving(name: name, resolvedEndpoint: nil)
        }
    }

    private func finishResolving(name: String, resolvedEndpoint: NWEndpoint?) {
        guard let connection = resolvers.removeValue(forKey: name) else { return }
        connection.stateUpdateHandler = nil
        connection.cancel()
        if let url = Self.url(fromResolved: resolvedEndpoint) {
            resolvedURLs[name] = url
        }
        rebuildShares()
    }

    private static func url(fromResolved endpoint: NWEndpoint?) -> URL? {
        guard let endpoint, case let .hostPort(host, port) = endpoint else { return nil }
        let hostString: String
        switch host {
        case let .name(hostName, _):
            hostString = hostName.hasSuffix(".") ? String(hostName.dropLast()) : hostName
        case let .ipv4(address):
            hostString = "\(address)"
        default:
            // IPv6 literals need bracket/zone-id handling that the `.local` fallback sidesteps.
            return nil
        }
        var components = URLComponents()
        components.scheme = smbScheme
        components.host = hostString
        let portValue = Int(port.rawValue)
        if portValue != 0, portValue != defaultSMBPort {
            components.port = portValue
        }
        return components.url
    }

    private static func fallbackURL(forServiceName name: String) -> URL? {
        guard let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else { return nil }
        return URL(string: "\(smbScheme)://\(encodedName)\(mdnsHostSuffix)")
    }
}
