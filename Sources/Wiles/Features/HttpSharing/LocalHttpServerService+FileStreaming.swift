import Foundation
import GitBeacon
import Network

/// File-body streaming for `LocalHttpServerService`: `Range` parsing, the `200`/`206`/`416`
/// decision, and the chunked send loop. Split from the main file to keep it under the line cap.
extension LocalHttpServerService {
    enum RequestedByteRange {
        case none
        case satisfiable(start: Int, end: Int)
        case unsatisfiable
    }

    /// Chunk size for streaming file bodies: bounds peak memory usage while serving large files
    /// instead of buffering the entire file into a single `Data` object.
    static let fileStreamChunkSize = 64 * 1024

    /// Parses a single `bytes=` range spec — the only form this server supports. Multi-range specs
    /// and non-`bytes` units are treated as absent (RFC 7233 permits ignoring an unparseable Range).
    nonisolated static func parseByteRange(_ header: String?, fileSize: Int) -> RequestedByteRange {
        guard let header else { return .none }
        let value = header.dropFirst("range:".count).trimmingCharacters(in: .whitespaces)
        guard value.lowercased().hasPrefix("bytes=") else { return .none }
        let spec = value.dropFirst("bytes=".count).trimmingCharacters(in: .whitespaces)
        guard !spec.contains(","), spec.contains("-") else { return .none }
        let parts = spec.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let startStr = String(parts[0])
        let endStr = parts.count > 1 ? String(parts[1]) : ""
        guard fileSize > 0 else { return .unsatisfiable }

        if startStr.isEmpty {
            guard let suffix = Int(endStr), suffix > 0 else { return .none }
            return .satisfiable(start: max(0, fileSize - suffix), end: fileSize - 1)
        }
        guard let start = Int(startStr), start >= 0 else { return .none }
        guard start < fileSize else { return .unsatisfiable }
        if endStr.isEmpty {
            return .satisfiable(start: start, end: fileSize - 1)
        }
        guard let parsedEnd = Int(endStr), parsedEnd >= start else { return .none }
        return .satisfiable(start: start, end: min(parsedEnd, fileSize - 1))
    }

    func streamFile(at fileURL: URL, connection: NWConnection, rangeHeader: String?) {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let fileSize = (attributes[.size] as? Int) ?? 0
            let fileHandle = try FileHandle(forReadingFrom: fileURL)

            switch Self.parseByteRange(rangeHeader, fileSize: fileSize) {
            case .unsatisfiable:
                try? fileHandle.close()
                sendResponse(
                    connection: connection, statusCode: HTTPStatus.rangeNotSatisfiable,
                    body: Data("Range Not Satisfiable".utf8),
                    extraHeaders: ["Content-Range": "bytes */\(fileSize)", "Accept-Ranges": "bytes"])
            case let .satisfiable(start, end):
                try? fileHandle.seek(toOffset: UInt64(start))
                let header = Self.streamResponseHeader(
                    status: HTTPStatus.partialContent, contentLength: end - start + 1,
                    extraHeaders: [
                        ("Content-Range", "bytes \(start)-\(end)/\(fileSize)"),
                        ("Accept-Ranges", "bytes")
                    ])
                sendStreamHeader(header, fileHandle: fileHandle, connection: connection, remaining: end - start + 1)
            case .none:
                let header = Self.streamResponseHeader(
                    status: HTTPStatus.ok, contentLength: fileSize, extraHeaders: [("Accept-Ranges", "bytes")])
                sendStreamHeader(header, fileHandle: fileHandle, connection: connection, remaining: fileSize)
            }
        } catch {
            ErrorReporter.report(error, context: "Streaming file over local HTTP share")
            sendResponse(connection: connection, statusCode: HTTPStatus.internalServerError, body: Data("Error reading file".utf8))
        }
    }

    /// Delegates to the shared list-based `httpHead` builder so the two response paths can't drift
    /// (finding LL-055). Keeps the historical line order: fixed headers, then range headers, then
    /// `Connection: close`.
    private nonisolated static func streamResponseHeader(status: Int, contentLength: Int, extraHeaders: [(String, String)]) -> Data {
        httpHead(statusCode: status, headers: [
            ("Content-Length", "\(contentLength)"),
            ("Content-Type", "application/octet-stream")
        ] + extraHeaders + [("Connection", "close")])
    }

    private func sendStreamHeader(_ header: Data, fileHandle: FileHandle, connection: NWConnection, remaining: Int) {
        connection.send(content: header, completion: .contentProcessed { [weak self] error in
            guard let self, error == nil else {
                try? fileHandle.close()
                connection.cancel()
                self?.removeConnection(connection)
                return
            }
            sendNextChunk(fileHandle: fileHandle, connection: connection, remaining: remaining)
        })
    }

    private func sendNextChunk(fileHandle: FileHandle, connection: NWConnection, remaining: Int) {
        guard remaining > 0 else {
            try? fileHandle.close()
            connection.cancel()
            removeConnection(connection)
            return
        }
        let chunk: Data?
        do {
            chunk = try fileHandle.read(upToCount: min(Self.fileStreamChunkSize, remaining))
        } catch {
            // A mid-stream read failure isn't EOF: the client has already been promised
            // `Content-Length` bytes and will now get fewer. Log it and drop the connection so
            // the client sees a reset rather than a clean, "complete" close.
            ErrorReporter.report(error, context: "Reading file mid-stream over local HTTP share (client download will be truncated)")
            try? fileHandle.close()
            connection.cancel()
            removeConnection(connection)
            return
        }

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
            sendNextChunk(fileHandle: fileHandle, connection: connection, remaining: remaining - chunk.count)
        })
    }
}
