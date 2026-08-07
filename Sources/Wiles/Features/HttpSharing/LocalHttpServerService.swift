import Foundation
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

    private init() {}

    public func start(sharing folder: URL) {
        sharedFolder = folder
        do {
            let parameters = NWParameters.tcp
            listener = try NWListener(using: parameters, on: port)

            listener?.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    guard let self = self else { return }
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

            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }

            listener?.start(queue: queue)
        } catch {
            stop()
        }
    }

    public func stop() {
        listener?.cancel()
        listener = nil
        queue.async { [weak self] in
            guard let self = self else { return }
            for conn in self.connections {
                conn.cancel()
            }
            self.connections.removeAll()
        }
        sharedFolder = nil
        Task { @MainActor in
            isRunning = false
            serverURL = nil
        }
    }

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
                        getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                    &hostname, socklen_t(hostname.count),
                                    nil, socklen_t(0), NI_NUMERICHOST)
                        let hostnameBytes = Array(hostname.map { UInt8(bitPattern: $0) }.prefix(while: { $0 != 0 }))
                        address = String(bytes: hostnameBytes, encoding: .utf8) ?? ""
                        break
                    }
                }
            }
            freeifaddrs(ifaddr)
        }

        let finalServerURL: String
        if let ip = address {
            finalServerURL = "http://\(ip):\(port.rawValue)"
        } else {
            finalServerURL = "http://localhost:\(port.rawValue)"
        }
        Task { @MainActor in
            self.serverURL = finalServerURL
        }
    }

    private func handleConnection(_ connection: NWConnection) {
        connections.append(connection)
        connection.start(queue: queue)
        receiveRequest(on: connection)
    }

    private func receiveRequest(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] content, _, _, _ in
            guard let self = self, let content = content, !content.isEmpty else {
                connection.cancel()
                self?.connections.removeAll(where: { $0 === connection })
                return
            }
            guard let requestStr = String(bytes: content, encoding: .utf8) else {
                connection.cancel()
                return
            }
            self.processRequest(requestStr, connection: connection)
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

        if path == "/" || path.isEmpty {
            serveDirectoryListing(folder: folder, connection: connection)
            return
        }

        serveFile(path: path, folder: folder, connection: connection)
    }

    private func serveDirectoryListing(folder: URL, connection: NWConnection) {
        do {
            let urls = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            var html = "<html><head><title>Wiles - Shared Folder</title>"
            html += "<meta name='viewport' content='width=device-width, initial-scale=1.0'></head>"
            html += "<body style='font-family: system-ui; max-width: 800px; margin: 0 auto; padding: 20px;'>"
            html += "<h1>Shared: \(folder.lastPathComponent)</h1><hr/><ul>"
            for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                let name = url.lastPathComponent
                let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
                html += "<li style='margin-bottom: 8px;'><a href=\"/\(encoded)\" style='text-decoration: none; color: #0066cc;'>\(name)</a></li>"
            }
            html += "</ul></body></html>"
            sendResponse(connection: connection, statusCode: HTTPStatus.ok, body: Data(html.utf8), contentType: "text/html")
        } catch {
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

    // Chunk size for streaming file bodies: bounds peak memory usage while serving large files
    // instead of buffering the entire file into a single `Data` object (see `streamFile`).
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
            connection.send(content: Data(headerStr.utf8), completion: .contentProcessed({ [weak self] error in
                guard let self = self, error == nil else {
                    try? fileHandle.close()
                    connection.cancel()
                    self?.connections.removeAll(where: { $0 === connection })
                    return
                }
                self.sendNextChunk(fileHandle: fileHandle, connection: connection)
            }))
        } catch {
            sendResponse(connection: connection, statusCode: HTTPStatus.internalServerError, body: Data("Error reading file".utf8))
        }
    }

    private func sendNextChunk(fileHandle: FileHandle, connection: NWConnection) {
        let chunk = try? fileHandle.read(upToCount: Self.fileStreamChunkSize)

        guard let chunk = chunk, !chunk.isEmpty else {
            try? fileHandle.close()
            connection.cancel()
            connections.removeAll(where: { $0 === connection })
            return
        }

        connection.send(content: chunk, completion: .contentProcessed({ [weak self] error in
            guard let self = self, error == nil else {
                try? fileHandle.close()
                connection.cancel()
                self?.connections.removeAll(where: { $0 === connection })
                return
            }
            self.sendNextChunk(fileHandle: fileHandle, connection: connection)
        }))
    }

    private func sendResponse(connection: NWConnection, statusCode: Int, body: Data, contentType: String = "text/plain") {
        let statusText = HTTPURLResponse.localizedString(forStatusCode: statusCode)
        let headerStr = """
        HTTP/1.1 \(statusCode) \(statusText)\r
        Content-Length: \(body.count)\r
        Content-Type: \(contentType)\r
        Connection: close\r
        \r

        """
        var responseData = Data(headerStr.utf8)
        responseData.append(body)

        connection.send(content: responseData, completion: .contentProcessed({ [weak self] _ in
            connection.cancel()
            self?.connections.removeAll(where: { $0 === connection })
        }))
    }
}
