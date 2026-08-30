import CryptoKit
import Foundation
import GitBeacon
import Network
import Observation

@Observable
public final class LocalHttpServerService: @unchecked Sendable {
    public static let shared = LocalHttpServerService()

    // Observed surface — all `@MainActor`. Everything below is `queue`-owned state, kept
    // `@ObservationIgnored` so a background mutation never touches the ObservationRegistrar.
    @MainActor public var isRunning: Bool = false
    @MainActor public var serverURL: String?
    /// Set when `start(sharing:password:)` fails to stand up the listener, so `HttpShareSheet`
    /// (stuck otherwise on "Starting server…") has something to show and retry from.
    @MainActor public var startError: String?

    @ObservationIgnored var sharedFolder: URL?
    /// The port the server is (or last tried) listening on. Seeded to `defaultPort` and bumped to
    /// the next free port in `portScanRange` when that one is already taken (another app, or a
    /// second Wiles window already sharing).
    @ObservationIgnored var port: NWEndpoint.Port = LocalHttpServerService.defaultPort

    @ObservationIgnored private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.wiles.HttpServer")
    @ObservationIgnored private var connections: [NWConnection] = []
    @ObservationIgnored private var idleTimeoutWorkItems: [ObjectIdentifier: DispatchWorkItem] = [:]
    /// Bytes received so far per connection, accumulated until the `\r\n\r\n` request-head
    /// terminator arrives — HTTP does not guarantee the head lands in a single TCP segment.
    @ObservationIgnored private var requestBuffers: [ObjectIdentifier: Data] = [:]
    @ObservationIgnored private var requiredPassword: String?

    /// Caps concurrent connections for this local file-sharing feature — plenty for normal LAN
    /// browsing/downloads, low enough to bound memory/FD usage against a runaway client.
    private static let maxConcurrentConnections = 32
    /// A connection that opens and never sends a request is cancelled after this long instead of
    /// sitting in `connections` forever.
    private static let idleConnectionTimeout: TimeInterval = 15
    /// Upper bound on the buffered request head before the `\r\n\r\n` terminator; a client that
    /// keeps sending header bytes past this gets `431` instead of growing memory unbounded.
    private static let maxRequestHeadBytes = 32 * 1024
    /// Per-`connection.receive` read size while accumulating the request head.
    private static let requestReadChunkSize = 8192

    private init() { }

    public func start(sharing folder: URL, password: String? = nil) {
        // `sharedFolder`/`requiredPassword` are read from `processRequest`, which always runs on
        // `queue` (it's invoked from an `NWConnection` receive completion handler, and every
        // connection is started with `connection.start(queue: queue)`). Routing the write through
        // `queue.sync` here — the same mechanism already used for `listener` below — establishes a
        // proper happens-before relationship with that on-queue read, closing the data race.
        queue.sync {
            sharedFolder = folder
            requiredPassword = !(password?.isEmpty ?? true) ? password : nil
        }
        port = Self.firstAvailablePort(in: Self.portScanRange) ?? Self.defaultPort
        do {
            let parameters = NWParameters.tcp
            let newListener = try NWListener(using: parameters, on: port)

            newListener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    guard let self else { return }
                    switch state {
                    case .ready:
                        self.updateServerURL()
                        self.isRunning = true
                        self.startError = nil
                    case .failed, .cancelled:
                        self.isRunning = false
                        self.serverURL = nil
                    default:
                        break
                    }
                }
            }

            newListener.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }

            // `listener` is also read/written from stop() on whatever thread the caller uses, so
            // every mutation is routed through `queue` (the same queue connection handling runs on).
            queue.sync { listener = newListener }
            newListener.start(queue: queue)
        } catch {
            ErrorReporter.report(error, context: "Starting local HTTP share server")
            let message = error.localizedDescription
            Task { @MainActor [weak self] in self?.startError = message }
            stop()
        }
    }

    public func stop() {
        queue.sync {
            listener?.cancel()
            listener = nil
            for conn in connections {
                conn.cancel()
            }
            connections.removeAll()
            idleTimeoutWorkItems.values.forEach { $0.cancel() }
            idleTimeoutWorkItems.removeAll()
            requestBuffers.removeAll()
            sharedFolder = nil
            requiredPassword = nil
        }
        Task { @MainActor in
            isRunning = false
            serverURL = nil
        }
    }

    /// Only ever called from the @MainActor `Task` in `start()`'s stateUpdateHandler, so this stays
    /// synchronous on the actor instead of hopping into a redundant nested `Task { @MainActor in }`.
    @MainActor
    private func updateServerURL() {
        let address = candidateLANIPv4Address()

        let finalServerURL = if let ip = address {
            "http://\(ip):\(port.rawValue)"
        } else {
            "http://localhost:\(port.rawValue)"
        }
        serverURL = finalServerURL
    }

    private func handleConnection(_ connection: NWConnection) {
        guard connections.count < Self.maxConcurrentConnections else {
            connection.cancel()
            return
        }
        connections.append(connection)
        // Without this, a connection that never terminates via `sendResponse`/`streamFile` (one
        // that opens then goes silent) stays in `connections` forever — this plus the idle timeout
        // below are what actually prune it.
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .cancelled, .failed:
                self?.removeConnection(connection)
            default:
                break
            }
        }
        connection.start(queue: queue)
        scheduleIdleTimeout(for: connection)
        receiveRequest(on: connection)
    }

    private func scheduleIdleTimeout(for connection: NWConnection) {
        let workItem = DispatchWorkItem { [weak self] in
            connection.cancel()
            self?.removeConnection(connection)
        }
        idleTimeoutWorkItems[ObjectIdentifier(connection)] = workItem
        queue.asyncAfter(deadline: .now() + Self.idleConnectionTimeout, execute: workItem)
    }

    func removeConnection(_ connection: NWConnection) {
        connections.removeAll(where: { $0 === connection })
        let key = ObjectIdentifier(connection)
        idleTimeoutWorkItems.removeValue(forKey: key)?.cancel()
        requestBuffers.removeValue(forKey: key)
    }

    private func receiveRequest(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: Self.requestReadChunkSize) { [weak self] content, _, isComplete, _ in
            guard let self else {
                connection.cancel()
                return
            }
            handleReceivedBytes(content, isComplete: isComplete, on: connection)
        }
    }

    /// Accumulates request bytes per connection until the `\r\n\r\n` head terminator, then parses;
    /// caps the buffer at `maxRequestHeadBytes` (→ 431) and keeps reading while the head is partial.
    private func handleReceivedBytes(_ content: Data?, isComplete: Bool, on connection: NWConnection) {
        let key = ObjectIdentifier(connection)
        if let content, !content.isEmpty {
            // A real request byte arrived — this connection is no longer merely idle.
            idleTimeoutWorkItems.removeValue(forKey: key)?.cancel()
            requestBuffers[key, default: Data()].append(content)
        }

        guard let buffer = requestBuffers[key], !buffer.isEmpty else {
            connection.cancel()
            removeConnection(connection)
            return
        }

        if let headEnd = buffer.range(of: Data("\r\n\r\n".utf8)) {
            let head = buffer.subdata(in: buffer.startIndex ..< headEnd.lowerBound)
            requestBuffers.removeValue(forKey: key)
            guard let requestStr = String(bytes: head, encoding: .utf8) else {
                connection.cancel()
                removeConnection(connection)
                return
            }
            processRequest(requestStr, connection: connection)
            return
        }

        if buffer.count > Self.maxRequestHeadBytes {
            requestBuffers.removeValue(forKey: key)
            sendResponse(connection: connection, statusCode: HTTPStatus.requestHeaderFieldsTooLarge, body: Data("Request Header Fields Too Large".utf8))
            return
        }

        if isComplete {
            connection.cancel()
            removeConnection(connection)
            return
        }

        receiveRequest(on: connection)
    }

    private func processRequest(_ request: String, connection: NWConnection) {
        let lines = request.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else {
            sendResponse(connection: connection, statusCode: HTTPStatus.badRequest, body: Data("Bad Request".utf8))
            return
        }

        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2, parts[0] == "GET" else {
            sendResponse(connection: connection, statusCode: HTTPStatus.methodNotAllowed, body: Data("Method Not Allowed".utf8))
            return
        }

        let path = parts[1]
        let rangeHeader = lines.dropFirst().first(where: { $0.lowercased().hasPrefix("range:") })

        guard let folder = sharedFolder else {
            sendResponse(connection: connection, statusCode: HTTPStatus.internalServerError, body: Data("Internal Server Error".utf8))
            return
        }

        guard isAuthorized(headerLines: lines.dropFirst()) else {
            sendResponse(
                connection: connection,
                statusCode: HTTPStatus.unauthorized,
                body: Data("Unauthorized".utf8),
                extraHeaders: ["WWW-Authenticate": "Basic realm=\"Wiles Shared Folder\""])
            return
        }

        if path == "/" || path.isEmpty {
            serveDirectoryListing(folder: folder, connection: connection)
            return
        }

        serveFile(path: path, folder: folder, connection: connection, rangeHeader: rangeHeader)
    }

    /// Password is optional (rule: user chooses with/without auth, HttpShareSheet). When set, every
    /// request must present valid HTTP Basic credentials; the username is not checked, only the password.
    private func isAuthorized(headerLines: some Sequence<String>) -> Bool {
        guard let requiredPassword else { return true }

        guard let authHeader = headerLines.first(where: { $0.lowercased().hasPrefix("authorization:") }) else {
            return false
        }

        let value = authHeader.dropFirst("authorization:".count).trimmingCharacters(in: .whitespaces)
        guard value.hasPrefix("Basic ") else { return false }

        let encoded = value.dropFirst("Basic ".count)
        guard let decodedData = Data(base64Encoded: String(encoded)),
              let decoded = String(data: decodedData, encoding: .utf8) else {
            return false
        }

        let providedPassword = decoded.split(separator: ":", maxSplits: 1).count == 2
            ? String(decoded.split(separator: ":", maxSplits: 1)[1])
            : ""
        return Self.constantTimeEquals(providedPassword, requiredPassword)
    }

    /// Constant-time password check: compares SHA-256 digests so the work is fixed-width for any
    /// input, leaking neither a byte-by-byte mismatch position nor (via a length guard) the length.
    private static func constantTimeEquals(_ lhs: String, _ rhs: String) -> Bool {
        let lhsDigest = Array(SHA256.hash(data: Data(lhs.utf8)))
        let rhsDigest = Array(SHA256.hash(data: Data(rhs.utf8)))
        return zip(lhsDigest, rhsDigest).reduce(into: UInt8(0)) { result, pair in result |= pair.0 ^ pair.1 } == 0
    }

    /// The listing page is static HTML with inline styles and no scripts; lock everything else down
    /// so an entry name that still slipped markup through can't load or run anything.
    private static let listingContentSecurityPolicy =
        "default-src 'none'; style-src 'unsafe-inline'; img-src 'self'; base-uri 'none'; form-action 'none'"

    /// URL-path prefix (percent-encoded, leading slash, no trailing slash) locating `folder` inside
    /// the share root, so a nested listing's links stay root-relative like the request paths
    /// `serveFile` resolves. Empty when `folder` is the share root itself.
    private func listingLinkPrefix(for folder: URL) -> String {
        let rootComponents = (sharedFolder ?? folder).resolvingSymlinksInPath().pathComponents
        let relativeComponents = folder.resolvingSymlinksInPath().pathComponents.dropFirst(rootComponents.count)
        return relativeComponents.reduce(into: "") { result, component in
            result += "/" + (component.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? component)
        }
    }

    private func serveDirectoryListing(folder: URL, connection: NWConnection) {
        do {
            let urls = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isDirectoryKey])
            let linkPrefix = listingLinkPrefix(for: folder)
            let items = urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }).map { url -> String in
                let name = url.lastPathComponent
                let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
                let href = "\(linkPrefix)/\(encoded)" + (isDirectory ? "/" : "")
                let label = HTMLEscaping.escape(name) + (isDirectory ? "/" : "")
                let marker = isDirectory ? "\u{1F4C1} " : ""
                return "<li style='margin-bottom: 8px;'><a href=\"\(href)\" style='text-decoration: none; color: #0066cc;'>\(marker)\(label)</a></li>"
            }.joined()

            let rawLanguage = UserDefaults.standard.string(forKey: DefaultsKey.appLanguage.rawValue) ?? AppLanguage.system.rawValue
            let language = AppLanguage(rawValue: rawLanguage) ?? .system

            guard let html = TemplateRenderingService.render(
                resource: "SharedFolder",
                replacements: [
                    "FOLDER_NAME": HTMLEscaping.escape(folder.lastPathComponent),
                    "ITEMS": items,
                    "PAGE_TITLE": L10n.string(.sharedFolderPageTitle, lang: language),
                    "HEADING": L10n.string(.sharedFolderHeading, lang: language)
                ]) else {
                sendResponse(connection: connection, statusCode: HTTPStatus.internalServerError, body: Data("Missing SharedFolder template".utf8))
                return
            }
            sendResponse(
                connection: connection,
                statusCode: HTTPStatus.ok,
                body: Data(html.utf8),
                contentType: "text/html",
                extraHeaders: ["Content-Security-Policy": Self.listingContentSecurityPolicy])
        } catch {
            ErrorReporter.report(error, context: "Serving directory listing over local HTTP share")
            sendResponse(connection: connection, statusCode: HTTPStatus.internalServerError, body: Data("Error reading directory".utf8))
        }
    }

    private func serveFile(path: String, folder: URL, connection: NWConnection, rangeHeader: String?) {
        guard let decodedPath = path.removingPercentEncoding, Self.isSafeRequestPath(decodedPath) else {
            sendResponse(connection: connection, statusCode: HTTPStatus.badRequest, body: Data("Bad Request".utf8))
            return
        }

        let fileURL = folder.appendingPathComponent(String(decodedPath.dropFirst()))

        // Prevent Path Traversal. A plain hasPrefix(stdFolder) is not enough: it would also let a
        // sibling directory through (e.g. shared folder "/tmp/abc" would wrongly permit
        // "/tmp/abcDEF/secret.txt", since that string also starts with "/tmp/abc"). Requiring the
        // path separator boundary closes that gap. `resolvingSymlinksInPath()` (not just
        // `.standardizedFileURL`) also closes the symlink-escape gap, and works even when the final
        // path component doesn't exist yet, so this must run before the existence check below —
        // otherwise a traversal attempt with no real target behind it returns 404 instead of 403.
        let stdFolder = folder.resolvingSymlinksInPath().path
        let stdFile = fileURL.resolvingSymlinksInPath().path
        guard stdFile == stdFolder || stdFile.hasPrefix(stdFolder + "/") else {
            sendResponse(connection: connection, statusCode: HTTPStatus.forbidden, body: Data("Forbidden".utf8))
            return
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory) else {
            sendResponse(connection: connection, statusCode: HTTPStatus.notFound, body: Data("Not Found".utf8))
            return
        }

        // A subfolder link from the listing lands here too; recurse into its listing (still inside
        // the path-traversal boundary checked above) instead of trying to stream a directory.
        if isDirectory.boolValue {
            serveDirectoryListing(folder: fileURL, connection: connection)
            return
        }

        streamFile(at: fileURL, connection: connection, rangeHeader: rangeHeader)
    }

    func sendResponse(connection: NWConnection, statusCode: Int, body: Data, contentType: String = "text/plain", extraHeaders: [String: String] = [:]) {
        let statusText = HTTPURLResponse.localizedString(forStatusCode: statusCode)
        let extraHeaderLines = extraHeaders.map { "\($0.key): \($0.value)\r\n" }.joined()
        let headerStr = """
        HTTP/1.1 \(statusCode) \(statusText)\r
        Content-Length: \(body.count)\r
        Content-Type: \(contentType)\r
        Connection: close\r
        \(extraHeaderLines)\r

        """
        var responseData = Data(headerStr.utf8)
        responseData.append(body)

        connection.send(content: responseData, completion: .contentProcessed { [weak self] _ in
            connection.cancel()
            self?.removeConnection(connection)
        })
    }
}
