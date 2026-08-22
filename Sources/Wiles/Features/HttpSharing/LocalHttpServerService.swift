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

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.wiles.HttpServer")
    private var connections: [NWConnection] = []
    private var requiredPassword: String?

    private init() { }

    public func start(sharing folder: URL, password: String? = nil) {
        // `sharedFolder`/`requiredPassword` are read from `processRequest`, which always runs on
        // `queue` (it's invoked from an `NWConnection` receive completion handler, and every
        // connection is started with `connection.start(queue: queue)`). Routing the write through
        // `queue.sync` here — the same mechanism already used for `listener` below — establishes a
        // proper happens-before relationship with that on-queue read, closing the data race.
        queue.sync {
            sharedFolder = folder
            requiredPassword = (password?.isEmpty == false) ? password : nil
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
        // Get local IP
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                guard let interface = ptr?.pointee else { continue }
                let addrFamily = interface.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) {
                    let name = String(cString: interface.ifa_name)
                    if name == "en0" { // Wi-Fi interface usually
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(
                            interface.ifa_addr,
                            socklen_t(interface.ifa_addr.pointee.sa_len),
                            &hostname,
                            socklen_t(hostname.count),
                            nil,
                            socklen_t(0),
                            NI_NUMERICHOST)
                        let hostnameBytes = Array(hostname.map { UInt8(bitPattern: $0) }.prefix(while: { $0 != 0 }))
                        address = String(bytes: hostnameBytes, encoding: .utf8) ?? ""
                        break
                    }
                }
            }
            freeifaddrs(ifaddr)
        }

        let finalServerURL = if let ip = address {
            "http://\(ip):\(port.rawValue)"
        } else {
            "http://localhost:\(port.rawValue)"
        }
        serverURL = finalServerURL
    }

    private func handleConnection(_ connection: NWConnection) {
        connections.append(connection)
        connection.start(queue: queue)
        receiveRequest(on: connection)
    }

    private func receiveRequest(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] content, _, _, _ in
            guard let self, let content, !content.isEmpty else {
                connection.cancel()
                self?.connections.removeAll(where: { $0 === connection })
                return
            }
            guard let requestStr = String(bytes: content, encoding: .utf8) else {
                connection.cancel()
                connections.removeAll(where: { $0 === connection })
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
        // path separator boundary closes that gap.
        let stdFolder = folder.standardizedFileURL.path
        let stdFile = fileURL.standardizedFileURL.path
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
                    self?.connections.removeAll(where: { $0 === connection })
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
            connections.removeAll(where: { $0 === connection })
            return
        }

        connection.send(content: chunk, completion: .contentProcessed { [weak self] error in
            guard let self, error == nil else {
                try? fileHandle.close()
                connection.cancel()
                self?.connections.removeAll(where: { $0 === connection })
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
            self?.connections.removeAll(where: { $0 === connection })
        })
    }
}
