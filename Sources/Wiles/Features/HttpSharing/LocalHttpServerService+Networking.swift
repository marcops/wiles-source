import Foundation
import Network

/// Networking helpers for `LocalHttpServerService`, split out to keep the main file under the
/// line-count cap: choosing a free listen port, resolving a LAN-reachable IPv4 address, and
/// validating a decoded request path.
extension LocalHttpServerService {
    /// Preferred port; the URL stays memorable across sessions when it's free.
    static let defaultPort: NWEndpoint.Port = 8080
    /// If `defaultPort` is taken, try each of the next few ports before giving up.
    static let portScanRange: ClosedRange<UInt16> = 8080 ... 8089
    /// First port in `range` that a TCP socket can `bind()` right now, or `nil` if every one is
    /// taken. Best-effort (a port can still be claimed between this check and `NWListener` binding),
    /// but it turns the common "8080 already in use" case from a dead feature into a working one on
    /// the next port.
    static func firstAvailablePort(in range: ClosedRange<UInt16>) -> NWEndpoint.Port? {
        for candidate in range where isPortBindable(candidate) {
            return NWEndpoint.Port(rawValue: candidate)
        }
        return nil
    }

    private static func isPortBindable(_ port: UInt16) -> Bool {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        // Match Network.framework's own tolerance for a just-closed listener socket, so a port the
        // real `NWListener` could still reclaim isn't falsely reported as taken.
        var reuse: Int32 = 1
        _ = setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = INADDR_ANY
        let result = withUnsafePointer(to: &addr) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                bind(fd, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        return result == 0
    }

    /// AF_INET-capable interfaces that can carry a real address but aren't a LAN link a client on
    /// the same Wi-Fi network could actually reach — VPN tunnels, AWDL (AirDrop), bridges, etc.
    private static let virtualInterfaceNamePrefixes = ["utun", "awdl", "llw", "bridge", "stf", "gif", "ipsec", "lo"]

    /// Local IPv4 for LAN sharing: filters to up/running, non-loopback, non-link-local, non-virtual interfaces, preferring `en*` (Wi-Fi/Ethernet).
    func candidateLANIPv4Address() -> String? {
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

    /// Rejects a decoded request path with a NUL byte (`%00` — truncates C-API path handling
    /// downstream, so the traversal check and the actual open could disagree) or an empty path
    /// component (`//`), rather than relying on later normalization to paper over it.
    static func isSafeRequestPath(_ decodedPath: String) -> Bool {
        guard !decodedPath.contains("\0") else { return false }
        let interior = decodedPath.dropFirst().split(separator: "/", omittingEmptySubsequences: false)
        return !interior.dropLast().contains(where: \.isEmpty)
    }
}
