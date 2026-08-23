import Foundation
import GitBeacon
import Network

@Observable
public final class LocalHttpServerService: @unchecked Sendable {
    public static let shared = LocalHttpServerService()

    @MainActor public var isRunning: Bool = false
    public var sharedFolder: URL?
    public var port: NWEndpoint.Port = 8080
    @MainActor public var serverURL: String?
    /// Set when `start(sharing:password:)` fails to stand up the listener, so `HttpShareSheet`
    /// (stuck otherwise on "Starting server…") has something to show and retry from.
    @MainActor public var startError: String?

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.wiles.HttpServer")
    private var connections: [NWConnection] = []
    private var idleTimeoutWorkItems: [ObjectIdentifier: DispatchWorkItem] = [:]
    private var requiredPassword: String?

    /// Caps concurrent connections for this local file-sharing feature — plenty for normal LAN
    /// browsing/downloads, low enough to bound memory/FD usage against a runaway client.
    private static let maxConcurrentConnections = 32
    /// A connection that opens and never sends a request is cancelled after this long instead of
    /// sitting in `connections` forever.
    private static let idleConnectionTimeout: TimeInterval = 15

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
            sharedFolder = nil
            requiredPassword = nil
        }
        Task { @MainActor in
            isRunning = false
            serverURL = nil
        }
    }

    /// AF_INET-capable interfaces that can carry a real address but aren't a LAN link a client on
    /// the same Wi-Fi network could actually reach — VPN tunnels, AWDL (AirDrop), bridges, etc.
    private static let virtualInterfaceNamePrefixes = ["utun", "awdl", "llw", "bridge", "stf", "gif", "ipsec", "lo"]

    /// Local IPv4 for LAN sharing: filters to up/running, non-loopback, non-link-local, non-virtual interfaces, preferring `en*` (Wi-Fi/Ethernet).
    private func candidateLANIPv4Address() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var candidates: [(name: String, address: String)] = []
        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let current = ptr {
            defer { ptr = current.pointee.ifa_next }
            let interface = current.pointee
            guard interface.ifa_addr.pointee.sa_family == UInt8(AF_INET) else { continue }

            let flags = Int32(interface.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_RUNNING != 0, flags & IFF_LOOPBACK == 0 else { continue }

            let name = String(cString: interface.ifa_name)
            guard !Self.virtualInterfaceNamePrefixes.contains(where: { name.hasPrefix($0) }) else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(
                interface.ifa_addr,
                socklen_t(interface.ifa_addr.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                socklen_t(0),
                NI_NUMERICHOST) == 0 else { continue }
            let address = hostname.withUnsafeBufferPointer { buffer -> String in
                guard let baseAddress = buffer.baseAddress else { return "" }
                return String(cString: baseAddress)
            }
            guard !address.isEmpty, !address.hasPrefix("169.254.") else { continue }

            candidates.append((name, address))
        }

        return candidates.first(where: { $0.name.hasPrefix("en") })?.address ?? candidates.first?.address
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

    private func removeConnection(_ connection: NWConnection) {
        connections.removeAll(where: { $0 === connection })
        idleTimeoutWorkItems.removeValue(forKey: ObjectIdentifier(connection))?.cancel()
    }

    private func receiveRequest(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] content, _, _, _ in
            guard let self, let content, !content.isEmpty else {
                connection.cancel()
                self?.removeConnection(connection)
                return
            }
            // A real request line arrived — this connection is no longer merely idle.
            idleTimeoutWorkItems.removeValue(forKey: ObjectIdentifier(connection))?.cancel()
            guard let requestStr = String(bytes: content, encoding: .utf8) else {
                connection.cancel()
                removeConnection(connection)
                return
            }
            processRequest(requestStr, connection: connection)
        }
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

        serveFile(path: path, folder: folder, connection: connection)
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

    /// Avoids `==`'s early-exit-on-first-mismatch timing behavior, which could let a remote
    /// attacker infer the password byte-by-byte from response latency.
    private static func constantTimeEquals(_ lhs: String, _ rhs: String) -> Bool {
        let lhsBytes = Array(lhs.utf8)
        let rhsBytes = Array(rhs.utf8)
        guard lhsBytes.count == rhsBytes.count else { return false }
        return zip(lhsBytes, rhsBytes).reduce(into: UInt8(0)) { result, pair in result |= pair.0 ^ pair.1 } == 0
    }

    private func serveDirectoryListing(folder: URL, connection: NWConnection) {
        do {
            let urls = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            let items = urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }).map { url -> String in
                let name = url.lastPathComponent
                let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
                return "<li style='margin-bottom: 8px;'><a href=\"/\(encoded)\" style='text-decoration: none; color: #0066cc;'>\(name)</a></li>"
            }.joined()

            let rawLanguage = UserDefaults.standard.string(forKey: DefaultsKey.appLanguage.rawValue) ?? AppLanguage.system.rawValue
            let language = AppLanguage(rawValue: rawLanguage) ?? .system

            guard let html = TemplateRenderingService.render(
                resource: "SharedFolder",
                replacements: [
                    "FOLDER_NAME": folder.lastPathComponent,
                    "ITEMS": items,
                    "PAGE_TITLE": L10n.string(.sharedFolderPageTitle, lang: language),
                    "HEADING": L10n.string(.sharedFolderHeading, lang: language)
                ]) else {
                sendResponse(connection: connection, statusCode: HTTPStatus.internalServerError, body: Data("Missing SharedFolder template".utf8))
                return
            }
            sendResponse(connection: connection, statusCode: HTTPStatus.ok, body: Data(html.utf8), contentType: "text/html")
        } catch {
            ErrorReporter.report(error, context: "Serving directory listing over local HTTP share")
            sendResponse(connection: connection, statusCode: HTTPStatus.internalServerError, body: Data("Error reading directory".utf8))
        }
    }

    private func serveFile(path: String, folder: URL, connection: NWConnection) {
        guard let decodedPath = path.removingPercentEncoding else {
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

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            sendResponse(connection: connection, statusCode: HTTPStatus.notFound, body: Data("Not Found".utf8))
            return
        }

        streamFile(at: fileURL, connection: connection)
    }

    /// Chunk size for streaming file bodies: bounds peak memory usage while serving large files
    /// instead of buffering the entire file into a single `Data` object (see `streamFile`).
    private static let fileStreamChunkSize = 64 * 1024

    private func streamFile(at fileURL: URL, connection: NWConnection) {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let fileSize = (attributes[.size] as? Int) ?? 0
            let fileHandle = try FileHandle(forReadingFrom: fileURL)
            let statusText = HTTPURLResponse.localizedString(forStatusCode: HTTPStatus.ok)
            let headerStr = """
            HTTP/1.1 \(HTTPStatus.ok) \(statusText)\r
            Content-Length: \(fileSize)\r
            Content-Type: application/octet-stream\r
            Connection: close\r
            \r

            """
            connection.send(content: Data(headerStr.utf8), completion: .contentProcessed { [weak self] error in
                guard let self, error == nil else {
                    try? fileHandle.close()
                    connection.cancel()
                    self?.removeConnection(connection)
                    return
                }
                sendNextChunk(fileHandle: fileHandle, connection: connection)
            })
        } catch {
            ErrorReporter.report(error, context: "Streaming file over local HTTP share")
            sendResponse(connection: connection, statusCode: HTTPStatus.internalServerError, body: Data("Error reading file".utf8))
        }
    }

    private func sendNextChunk(fileHandle: FileHandle, connection: NWConnection) {
        let chunk = try? fileHandle.read(upToCount: Self.fileStreamChunkSize)

        guard let chunk, !chunk.isEmpty else {
            try? fileHandle.close()
            connection.cancel()
            removeConnection(connection)
            return
        }

        connection.send(content: chunk, completion: .contentProcessed { [weak self] error in
            guard let self, error == nil else {
                try? fileHandle.close()
                connection.cancel()
                self?.removeConnection(connection)
                return
            }
            sendNextChunk(fileHandle: fileHandle, connection: connection)
        })
    }

    private func sendResponse(connection: NWConnection, statusCode: Int, body: Data, contentType: String = "text/plain", extraHeaders: [String: String] = [:]) {
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
