import Foundation

public struct POSIXPermissions: Sendable, Equatable {
    public var ownerRead: Bool
    public var ownerWrite: Bool
    public var ownerExecute: Bool

    public var groupRead: Bool
    public var groupWrite: Bool
    public var groupExecute: Bool

    public var othersRead: Bool
    public var othersWrite: Bool
    public var othersExecute: Bool

    /// setuid/setgid/sticky (`0o7000`). The permissions UI only edits the `rwx` bits, so these are
    /// carried through untouched instead of being silently cleared on a round-trip.
    public var specialBits: Int

    private var packedOctalValue: Int {
        let owner = (ownerRead ? 4 : 0) + (ownerWrite ? 2 : 0) + (ownerExecute ? 1 : 0)
        let group = (groupRead ? 4 : 0) + (groupWrite ? 2 : 0) + (groupExecute ? 1 : 0)
        let others = (othersRead ? 4 : 0) + (othersWrite ? 2 : 0) + (othersExecute ? 1 : 0)
        return (specialBits & 0o7000) | (owner << 6) | (group << 3) | others
    }

    public var octalString: String {
        String(format: "%04o", packedOctalValue)
    }

    public init(posixPermissions: Int16) {
        let octal = Int(posixPermissions)
        specialBits = octal & 0o7000
        ownerRead = (octal & 0o400) != 0
        ownerWrite = (octal & 0o200) != 0
        ownerExecute = (octal & 0o100) != 0

        groupRead = (octal & 0o040) != 0
        groupWrite = (octal & 0o020) != 0
        groupExecute = (octal & 0o010) != 0

        othersRead = (octal & 0o004) != 0
        othersWrite = (octal & 0o002) != 0
        othersExecute = (octal & 0o001) != 0
    }

    public var octalInt: Int16 {
        Int16(packedOctalValue)
    }
}
