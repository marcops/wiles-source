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
        for conn in connections {
            conn.cancel()
        }
        connections.removeAll()
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
                        address = String(decoding: hostname.map { UInt8(bitPattern: $0) }.prefix(while: { $0 != 0 }), as: UTF8.self)
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
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] content, _, isComplete, error in
            guard let self = self, let content = content, !content.isEmpty else {
                connection.cancel()
                self?.connections.removeAll(where: { $0 === connection })
                return
            }
            let requestStr = String(data: content, encoding: .utf8) ?? ""
            self.processRequest(requestStr, connection: connection)
        }
    }
    
    private func processRequest(_ request: String, connection: NWConnection) {
        let lines = request.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else {
            sendResponse(connection: connection, statusCode: 400, body: "Bad Request".data(using: .utf8)!)
            return
        }
        
        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2, parts[0] == "GET" else {
            sendResponse(connection: connection, statusCode: 405, body: "Method Not Allowed".data(using: .utf8)!)
            return
        }
        
        let path = parts[1]
        
        guard let folder = sharedFolder else {
            sendResponse(connection: connection, statusCode: 500, body: "Internal Server Error".data(using: .utf8)!)
            return
        }
        
        // Serve Directory Listing
        if path == "/" || path.isEmpty {
            do {
                let urls = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
                var html = "<html><head><title>Wiles - Shared Folder</title><meta name='viewport' content='width=device-width, initial-scale=1.0'></head><body style='font-family: system-ui; max-width: 800px; margin: 0 auto; padding: 20px;'>"
                html += "<h1>Shared: \(folder.lastPathComponent)</h1><hr/><ul>"
                for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                    let name = url.lastPathComponent
                    let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
                    html += "<li style='margin-bottom: 8px;'><a href=\"/\(encoded)\" style='text-decoration: none; color: #0066cc;'>\(name)</a></li>"
                }
                html += "</ul></body></html>"
                sendResponse(connection: connection, statusCode: 200, body: html.data(using: .utf8)!, contentType: "text/html")
            } catch {
                sendResponse(connection: connection, statusCode: 500, body: "Error reading directory".data(using: .utf8)!)
            }
            return
        }
        
        // Serve File
        guard let decodedPath = path.removingPercentEncoding else {
            sendResponse(connection: connection, statusCode: 400, body: "Bad Request".data(using: .utf8)!)
            return
        }
        
        let fileURL = folder.appendingPathComponent(String(decodedPath.dropFirst()))
        
        // Prevent Path Traversal
        let stdFolder = folder.standardizedFileURL.path
        let stdFile = fileURL.standardizedFileURL.path
        guard stdFile.hasPrefix(stdFolder) else {
            sendResponse(connection: connection, statusCode: 403, body: "Forbidden".data(using: .utf8)!)
            return
        }
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                sendResponse(connection: connection, statusCode: 200, body: data, contentType: "application/octet-stream")
            } catch {
                sendResponse(connection: connection, statusCode: 500, body: "Error reading file".data(using: .utf8)!)
            }
        } else {
            sendResponse(connection: connection, statusCode: 404, body: "Not Found".data(using: .utf8)!)
        }
    }
    
    private func sendResponse(connection: NWConnection, statusCode: Int, body: Data, contentType: String = "text/plain") {
        let statusText = statusCode == 200 ? "OK" : (statusCode == 404 ? "Not Found" : "Error")
        let headerStr = """
        HTTP/1.1 \(statusCode) \(statusText)\r
        Content-Length: \(body.count)\r
        Content-Type: \(contentType)\r
        Connection: close\r
        \r
        
        """
        var responseData = headerStr.data(using: .utf8)!
        responseData.append(body)
        
        connection.send(content: responseData, completion: .contentProcessed({ [weak self] _ in
            connection.cancel()
            self?.connections.removeAll(where: { $0 === connection })
        }))
    }
}
