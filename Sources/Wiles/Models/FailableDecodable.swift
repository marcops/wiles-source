import Foundation

/// Decodes `T` but never throws for a bad element: `value` is `nil` when this array slot failed to
/// decode. Decode `[FailableDecodable<T>]` instead of `[T]` when one corrupt / forward-incompatible
/// record must not take the whole list down with it (finding ML-104).
public struct FailableDecodable<T: Decodable>: Decodable {
    public let value: T?

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try? container.decode(T.self)
    }
}
