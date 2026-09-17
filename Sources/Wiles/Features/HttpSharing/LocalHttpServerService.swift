import CryptoKit
import Foundation
import GitBeacon
import Network
import Observation

@Observable
public final class LocalHttpServerService: @unchecked Sendable {
    // Observed surface — all `@MainActor`. Everything below is `queue`-owned state, kept
    // `@ObservationIgnored` so a background mutation never touches the ObservationRegistrar.
    @MainActor public var isRunning: Bool = false
    @MainActor public var serverURL: String?
    /// Lets a dismissed `HttpShareSheet` be reopened onto the same running session.
    @MainActor public var sharingFolderURL: URL?
    @MainActor public var isPasswordProtected: Bool = false
    /// Set when `start(sharing:password:)` fails to stand up the listener, so `HttpShareSheet`
    /// (stuck otherwise on "Starting server…") has something to show and retry from.
    @MainActor public var startError: String?
    /// True from the moment `start(...)` is called until the listener is ready or has failed. The
    /// port scan (`waitForPortRelease`'s `Thread.sleep`, socket-probe loop) now runs off the main
    /// thread, so this is the immediate signal `HttpShareSheet` shows instead of `start()` blocking
    /// the UI for up to ~0.5s + probe time.
    @MainActor public var isStarting: Bool = false
    /// Bumped per `start(...)`; a stale async port-scan whose `finishStarting` lands after a newer
    /// `start(...)`/`stop()` checks this and bails.
    @MainActor @ObservationIgnored private var startGeneration = 0

    @ObservationIgnored var sharedFolder: URL?
    /// The port the server is (or last tried) listening on. Seeded to `defaultPort` and bumped to
    /// the next free port in `portScanRange` when that one is already taken (another app, or a
    /// second Wiles window already sharing).
    ///
    /// Unlike the other shared state (`sharedFolder`/`requiredPassword`/`listener`, guarded by
    /// `queue.sync`), `port` is `@MainActor`-only: written solely in `start()` and read in
    /// `start()`/`updateServerURL()`, all `@MainActor`. No `queue.sync` needed.
    @MainActor @ObservationIgnored var port: NWEndpoint.Port = LocalHttpServerService.defaultPort

    @ObservationIgnored private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.wiles.HttpServer")
    @ObservationIgnored private var connections: [NWConnection] = []
    @ObservationIgnored private var headDeadlineWorkItems: [ObjectIdentifier: DispatchWorkItem] = [:]
    /// Bytes received so far per connection, accumulated until the `\r\n\r\n` request-head
    /// terminator arrives — HTTP does not guarantee the head lands in a single TCP segment.
    @ObservationIgnored private var requestBuffers: [ObjectIdentifier: Data] = [:]
    @ObservationIgnored private var requiredPassword: String?

    /// Caps concurrent connections for this local file-sharing feature — plenty for normal LAN
    /// browsing/downloads, low enough to bound memory/FD usage against a runaway client.
    private static let maxConcurrentConnections = 32
    /// A connection must deliver its complete request head (`\r\n\r\n`) within this window of opening,
    /// or it's cancelled — not extended by incoming bytes, so a slowloris client can't hold its slot.
    private static let requestHeadDeadline: TimeInterval = 15
    /// Test seam: overrides `requestHeadDeadline` so a slowloris case doesn't need a real 15s wait.
    @ObservationIgnored var requestHeadDeadlineOverride: TimeInterval?
    /// Upper bound on the buffered request head before the `\r\n\r\n` terminator; a client that
    /// keeps sending header bytes past this gets `431` instead of growing memory unbounded.
    private static let maxRequestHeadBytes = 32 * 1024
    /// Per-`connection.receive` read size while accumulating the request head.
    private static let requestReadChunkSize = 8192

    /// One instance per `AppState` (per window), not a `.shared` singleton. Instances still
    /// coordinate over the TCP port by scanning `portScanRange`.
    public init() { }

    @MainActor
    public func start(sharing folder: URL, password: String? = nil) {
        // Tear down any listener/connections from a previous `start()` before standing up a new one.
        // Without this the earlier `NWListener` is orphaned — still bound to its port and with no
        // reference left to cancel it — so `firstAvailablePort` then skips that (still-occupied) port
        // and the new server lands on the next one. `stop` also clears `sharedFolder`/
        // `requiredPassword`, which is why they're (re)assigned only *after* it, just below.
        // `listener` is queue-owned state (see its declaration) — read it through `queue.sync`
        // like every other point-in-time access to it in this file (e.g. line ~127's `queue.sync {
        // listener = newListener }`), not directly on @MainActor, which raced a concurrent
        // `stop()`/`finishStarting()` mutating it on `queue`.
        let hadListener = queue.sync { listener != nil }
        let previousPort: UInt16? = hadListener ? port.rawValue : nil
        stop()
        startGeneration &+= 1
        let generation = startGeneration
        isStarting = true
        startError = nil
        sharingFolderURL = folder
        isPasswordProtected = !(password?.isEmpty ?? true)

        // Everything that can block — draining `stop()`'s async teardown, `waitForPortRelease`'s
        // `Thread.sleep`, the bind-probe loop in `firstAvailablePort` — runs on `queue`, off the
        // main thread. `sharedFolder`/`requiredPassword` are `queue`-owned state read from
        // `processRequest` (also on `queue`), so assigning them here gives the same happens-before
        // the old `queue.sync` did. Only the resolved port hops back to `@MainActor`.
        queue.async { [weak self] in
            guard let self else { return }
            sharedFolder = folder
            requiredPassword = !(password?.isEmpty ?? true) ? password : nil
            if let previousPort {
                Self.waitForPortRelease(previousPort, timeout: 0.5)
            }
            let chosen = Self.firstAvailablePort(in: Self.portScanRange, preferring: previousPort) ?? Self.defaultPort
            Task { @MainActor [weak self] in
                self?.finishStarting(on: chosen, generation: generation)
            }
        }
    }

    /// Second half of `start(...)`, back on `@MainActor` once the off-main port scan has picked a
    /// free port: stand up the `NWListener` (cheap, non-blocking) and publish state.
    @MainActor
    private func finishStarting(on chosenPort: NWEndpoint.Port, generation: Int) {
        guard generation == startGeneration, isStarting else { return } // superseded by a newer start()/stop()
        port = chosenPort
        do {
            let newListener = try NWListener(using: NWParameters.tcp, on: chosenPort)

            newListener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    guard let self else { return }
                    switch state {
                    case .ready:
                        self.updateServerURL()
                        self.isRunning = true
                        self.isStarting = false
                        self.startError = nil
                    case .failed, .cancelled:
                        self.isRunning = false
                        self.isStarting = false
                        self.serverURL = nil
                    default:
                        break
                    }
                }
            }

            newListener.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }

            queue.sync { listener = newListener }
            newListener.start(queue: queue)
        } catch {
            ErrorReporter.report(error, context: "Starting local HTTP share server")
            startError = error.localizedDescription
            isStarting = false
            stop()
        }
    }

    @MainActor
    public func stop() {
        // Flip the observable state on the actor immediately; the listener/connection teardown can
        // wait behind slow queue I/O (a stalled mount mid-`FileHandle.read`) — `queue.async`, not
        // `.sync`, so that never blocks the main thread. The serial queue keeps this ordered ahead
        // of any `queue.sync` a following `start()` enqueues.
        isRunning = false
        isStarting = false
        serverURL = nil
        sharingFolderURL = nil
        isPasswordProtected = false
        queue.async { [self] in
            listener?.cancel()
            listener = nil
            for conn in connections {
                conn.cancel()
            }
            connections.removeAll()
            headDeadlineWorkItems.values.forEach { $0.cancel() }
            headDeadlineWorkItems.removeAll()
            requestBuffers.removeAll()
            sharedFolder = nil
            requiredPassword = nil
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
        scheduleRequestHeadDeadline(for: connection)
        receiveRequest(on: connection)
    }

    private func scheduleRequestHeadDeadline(for connection: NWConnection) {
        let workItem = DispatchWorkItem { [weak self] in
            connection.cancel()
            self?.removeConnection(connection)
        }
        headDeadlineWorkItems[ObjectIdentifier(connection)] = workItem
        queue.asyncAfter(
            deadline: .now() + (requestHeadDeadlineOverride ?? Self.requestHeadDeadline), execute: workItem)
    }

    /// Cancels the request-head deadline once the head is in hand (parsed, or rejected as too large)
    /// so it can't fire against a connection that is now streaming a legitimate large download.
    private func clearRequestHeadDeadline(for key: ObjectIdentifier) {
        headDeadlineWorkItems.removeValue(forKey: key)?.cancel()
    }

    func removeConnection(_ connection: NWConnection) {
        connections.removeAll(where: { $0 === connection })
        let key = ObjectIdentifier(connection)
        clearRequestHeadDeadline(for: key)
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
            // Deliberately does NOT reset the request-head deadline — it's a hard limit on the
            // complete head, cleared only once the head is parsed or rejected.
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
            clearRequestHeadDeadline(for: key)
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
            clearRequestHeadDeadline(for: key)
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

        // `omittingEmptySubsequences` so a double space in the request line doesn't make `parts[1]` empty.
        let parts = firstLine.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
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

    /// The `contentsOfDirectory` + per-entry `isDirectory` reads + template render for a huge shared
    /// subfolder can take a while — running it on the serial `queue` would stall every other
    /// in-flight connection behind it. Build the whole response on a detached task
    /// (`buildDirectoryListing`, in `+DirectoryListing.swift`), then hop back to `queue` only for
    /// `sendResponse` (which mutates `queue`-owned connection state).
    private func serveDirectoryListing(folder: URL, connection: NWConnection) {
        let shareRoot = sharedFolder ?? folder
        Task.detached(priority: .userInitiated) { [weak self] in
            let result = Self.buildDirectoryListing(folder: folder, shareRoot: shareRoot)
            self?.queue.async { [weak self] in
                guard let self else { return }
                switch result {
                case let .ok(html):
                    sendResponse(
                        connection: connection, statusCode: HTTPStatus.ok, body: Data(html.utf8),
                        contentType: "text/html",
                        extraHeaders: ["Content-Security-Policy": Self.listingContentSecurityPolicy])
                case let .failure(status, message):
                    sendResponse(connection: connection, statusCode: status, body: Data(message.utf8))
                }
            }
        }
    }

    private func serveFile(path: String, folder: URL, connection: NWConnection, rangeHeader: String?) {
        guard let decodedPath = path.removingPercentEncoding, Self.isSafeRequestPath(decodedPath) else {
            sendResponse(connection: connection, statusCode: HTTPStatus.badRequest, body: Data("Bad Request".utf8))
            return
        }

        // Hidden entries aren't listed (see `serveDirectoryListing`) and a direct request for one
        // (`/.env`, `/.git/config`) is refused too — same secret-leak reasoning.
        guard !decodedPath.split(separator: "/").contains(where: { $0.hasPrefix(".") }) else {
            sendResponse(connection: connection, statusCode: HTTPStatus.forbidden, body: Data("Forbidden".utf8))
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
        let headers: [(String, String)] = [
            ("Content-Length", "\(body.count)"),
            ("Content-Type", contentType),
            ("Connection", "close")
        ] + extraHeaders.map { ($0.key, $0.value) }
        var responseData = Self.httpHead(statusCode: statusCode, headers: headers)
        responseData.append(body)

        connection.send(content: responseData, completion: .contentProcessed { [weak self] _ in
            connection.cancel()
            self?.removeConnection(connection)
        })
    }

    /// The one HTTP response-head builder: status line + one CRLF-terminated line per header +
    /// the blank line. Built from a `(name, value)` list — never a template string — so a stray
    /// edit can't drop a `\r` and desync the frame. Shared by `sendResponse` and the file-streaming
    /// path's `streamResponseHeader`.
    nonisolated static func httpHead(statusCode: Int, headers: [(String, String)]) -> Data {
        let statusText = HTTPURLResponse.localizedString(forStatusCode: statusCode)
        let block = "HTTP/1.1 \(statusCode) \(statusText)\r\n"
            + headers.map { "\($0.0): \($0.1)\r\n" }.joined()
            + "\r\n"
        return Data(block.utf8)
    }
}
